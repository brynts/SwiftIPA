import Foundation

enum InspectorService {
    static func inspect(ipaURL: URL) throws -> InspectionReport {
        let extracted = try IPAService.extract(ipaURL: ipaURL)
        defer { extracted.cleanUp() }
        let metadata = try IPAService.metadata(from: extracted)

        let fileManager = FileManager.default
        var executables: [MachOSummary] = []
        var findings: [InspectionFinding] = []

        let enumerator = fileManager.enumerator(at: extracted.appFolder, includingPropertiesForKeys: [.fileSizeKey])
        var frameworkNames: [String] = []
        var pluginNames: [String] = []

        while let item = enumerator?.nextObject() as? URL {
            if item.pathExtension == "framework" {
                frameworkNames.append(item.deletingPathExtension().lastPathComponent)
            }
            if item.pathExtension == "appex" {
                pluginNames.append(item.deletingPathExtension().lastPathComponent)
            }

            guard MachOImage.isMachO(url: item) else { continue }
            guard let image = try? MachOImage(url: item) else { continue }
            let size = (try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

            let relativePath = item.path.replacingOccurrences(of: extracted.appFolder.path + "/", with: "")
            executables.append(MachOSummary(
                path: relativePath,
                architectures: image.architectures,
                isEncrypted: image.isEncrypted,
                isSigned: image.isSigned,
                linkedDylibs: image.linkedDylibs,
                rpaths: image.rpaths,
                byteSize: Int64(size)
            ))

            if image.isEncrypted {
                findings.append(InspectionFinding(
                    severity: .warning,
                    title: String(localized: "Encrypted binary"),
                    detail: String(localized: "\(relativePath) still has its App Store FairPlay encryption. Signing will proceed, but this executable is likely a cracked or DRM-protected build.")
                ))
            }
            if !image.architectures.contains(where: { $0.hasPrefix("arm") }) {
                findings.append(InspectionFinding(
                    severity: .blocker,
                    title: String(localized: "No arm64 slice"),
                    detail: String(localized: "\(relativePath) has no arm64 architecture and can't run on a real iPhone or iPad.")
                ))
            }
        }

        if metadata.hasWatchApp {
            findings.append(InspectionFinding(
                severity: .info,
                title: String(localized: "Bundled Watch app"),
                detail: String(localized: "This IPA embeds a watchOS companion app. Remove it in Modifiers if you don't need it.")
            ))
        }
        if !metadata.plugins.isEmpty {
            findings.append(InspectionFinding(
                severity: .info,
                title: String(localized: "\(metadata.plugins.count) extension(s)"),
                detail: String(localized: "App extensions and plug-ins increase signing time and can fail on some certificates.")
            ))
        }

        let size = (try? fileManager.allocatedSizeOfDirectory(at: extracted.appFolder)) ?? 0
        let localizations = (try? fileManager.contentsOfDirectory(atPath: extracted.appFolder.path))?
            .filter { $0.hasSuffix(".lproj") }
            .map { ($0 as NSString).deletingPathExtension } ?? []

        return InspectionReport(
            appName: metadata.name,
            bundleIdentifier: metadata.bundleIdentifier,
            version: metadata.version,
            build: metadata.build,
            minimumOSVersion: metadata.minimumOSVersion,
            supportedDevices: [],
            uncompressedSize: size,
            executables: executables,
            frameworks: frameworkNames,
            plugins: pluginNames,
            hasWatchApp: metadata.hasWatchApp,
            entitlements: nil,
            urlSchemes: metadata.urlSchemes,
            localizations: localizations,
            findings: findings.sorted { $0.severity > $1.severity }
        )
    }
}

private extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> Int64 {
        var total: Int64 = 0
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }
}
