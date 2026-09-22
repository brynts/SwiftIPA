import Foundation

enum RepositoryServiceError: LocalizedError {
    case invalidResponse
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return String(localized: "Couldn't reach that source.")
        case .invalidFormat: return String(localized: "This doesn't look like an AltStore or ESign source.")
        }
    }
}

enum RepositoryService {
    static func fetch(url: URL) async throws -> RepositoryPayload {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw RepositoryServiceError.invalidResponse
        }
        do {
            return try JSONDecoder().decode(RepositoryPayload.self, from: data)
        } catch {
            throw RepositoryServiceError.invalidFormat
        }
    }

    static func download(_ version: RepositoryAppVersion, progress: @escaping (Double) -> Void) async throws -> URL {
        let (bytes, response) = try await URLSession.shared.bytes(from: version.downloadURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw RepositoryServiceError.invalidResponse
        }
        let expected = httpResponse.expectedContentLength
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).ipa")
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        var received: Int64 = 0
        var buffer = Data()
        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= 262_144 {
                handle.write(buffer)
                received += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                if expected > 0 {
                    progress(Double(received) / Double(expected))
                }
            }
        }
        if !buffer.isEmpty {
            handle.write(buffer)
        }
        progress(1.0)
        return destination
    }
}
