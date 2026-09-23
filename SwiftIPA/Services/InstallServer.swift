import Foundation
import Network
import Security

enum InstallServerError: LocalizedError {
    case noIdentity
    case noAddress
    case listenerFailed(String)

    var errorDescription: String? {
        switch self {
        case .noIdentity: return String(localized: "SwiftIPA couldn't prepare its local server certificate.")
        case .noAddress: return String(localized: "SwiftIPA couldn't find your device's Wi-Fi address. Make sure you're connected to Wi-Fi.")
        case .listenerFailed(let message): return message
        }
    }
}

final class InstallServer {
    static let shared = InstallServer()

    private var listener: NWListener?
    private var ipaURL: URL?
    private var appName = ""
    private var bundleIdentifier = ""
    private var version = ""
    private var scheme = "http"
    private var host = "127.0.0.1"
    private var port: UInt16 = 8442
    private let queue = DispatchQueue(label: "com.xsxs18.SwiftIPA.InstallServer")

    private init() {}

    func startInstall(
        ipaURL: URL,
        appName: String,
        bundleIdentifier: String,
        version: String,
        useSecureConnection: Bool = false,
        useLocalNetworkAddress: Bool = false
    ) async throws -> URL {
        stop()

        self.ipaURL = ipaURL
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.scheme = useSecureConnection ? "https" : "http"
        self.port = useSecureConnection ? 8443 : 8442

        if useLocalNetworkAddress {
            guard let address = Self.wifiIPAddress() else { throw InstallServerError.noAddress }
            self.host = address
        } else {
            self.host = "127.0.0.1"
        }

        let parameters: NWParameters
        if useSecureConnection {
            let (identity, _, _) = try LocalServerIdentity.ensureIdentity()
            guard let secIdentity = sec_identity_create(identity) else { throw InstallServerError.noIdentity }
            let tlsOptions = NWProtocolTLS.Options()
            sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, secIdentity)
            parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        } else {
            parameters = NWParameters.tcp
        }
        parameters.allowLocalEndpointReuse = true

        let newListener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        listener = newListener

        newListener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        let hasResumed = NSLock()
        var didResume = false

        return try await withCheckedThrowingContinuation { continuation in
            newListener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                hasResumed.lock()
                let alreadyResumed = didResume
                if !alreadyResumed { didResume = true }
                hasResumed.unlock()
                guard !alreadyResumed else { return }

                switch state {
                case .ready:
                    let manifestURL = "\(self.scheme)://\(self.host):\(self.port)/manifest.plist"
                    let itms = "itms-services://?action=download-manifest&url=\(manifestURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? manifestURL)"
                    continuation.resume(returning: URL(string: itms)!)
                case .failed(let error):
                    continuation.resume(throwing: InstallServerError.listenerFailed(error.localizedDescription))
                default:
                    hasResumed.lock()
                    didResume = false
                    hasResumed.unlock()
                }
            }
            newListener.start(queue: self.queue)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        readRequest(connection: connection, buffer: Data())
    }

    private func readRequest(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            if let range = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                let requestLine = String(data: headerData, encoding: .utf8)?.components(separatedBy: "\r\n").first ?? ""
                self.respond(to: requestLine, on: connection)
                return
            }

            if isComplete || error != nil || buffer.count > 8192 {
                connection.cancel()
                return
            }

            self.readRequest(connection: connection, buffer: buffer)
        }
    }

    private func respond(to requestLine: String, on connection: NWConnection) {
        let parts = requestLine.split(separator: " ")
        let path = parts.count > 1 ? String(parts[1]) : "/"

        if path.hasPrefix("/manifest.plist") {
            sendManifest(on: connection)
        } else if path.hasPrefix("/app.ipa") {
            sendIPA(on: connection)
        } else {
            let body = "Not Found".data(using: .utf8)!
            sendResponse(status: "404 Not Found", contentType: "text/plain", body: body, on: connection)
        }
    }

    private func sendManifest(on connection: NWConnection) {
        let payload: [String: Any] = [
            "items": [
                [
                    "assets": [
                        [
                            "kind": "software-package",
                            "url": "\(scheme)://\(host):\(port)/app.ipa"
                        ]
                    ],
                    "metadata": [
                        "bundle-identifier": bundleIdentifier,
                        "bundle-version": version,
                        "kind": "software",
                        "title": appName
                    ]
                ]
            ]
        ]

        guard let data = try? PropertyListSerialization.data(fromPropertyList: payload, format: .xml, options: 0) else {
            connection.cancel()
            return
        }
        sendResponse(status: "200 OK", contentType: "application/xml", body: data, on: connection)
    }

    private func sendIPA(on connection: NWConnection) {
        guard let ipaURL, let handle = try? FileHandle(forReadingFrom: ipaURL) else {
            sendResponse(status: "404 Not Found", contentType: "text/plain", body: Data(), on: connection)
            return
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: ipaURL.path)[.size] as? Int64) ?? 0

        let header = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: \(size)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] _ in
            self?.streamFile(handle: handle, connection: connection)
        })
    }

    private func streamFile(handle: FileHandle, connection: NWConnection) {
        guard let chunk = try? handle.read(upToCount: 262_144), !chunk.isEmpty else {
            try? handle.close()
            connection.cancel()
            return
        }
        connection.send(content: chunk, completion: .contentProcessed { [weak self] _ in
            self?.streamFile(handle: handle, connection: connection)
        })
    }

    private func sendResponse(status: String, contentType: String, body: Data, on connection: NWConnection) {
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var payload = Data(header.utf8)
        payload.append(body)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func wifiIPAddress() -> String? {
        var address: String?
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = firstInterface
        while let interface = pointer {
            defer { pointer = interface.pointee.ifa_next }
            let family = interface.pointee.ifa_addr.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.pointee.ifa_name)
            guard name == "en0" else { continue }

            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                interface.pointee.ifa_addr,
                socklen_t(interface.pointee.ifa_addr.pointee.sa_len),
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            address = String(cString: hostBuffer)
        }
        return address
    }
}
