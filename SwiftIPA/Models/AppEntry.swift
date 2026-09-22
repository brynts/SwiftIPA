import Foundation

struct AppEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var bundleIdentifier: String
    var version: String
    var build: String
    var minimumOSVersion: String
    var fileName: String
    var iconFileName: String?
    var byteSize: Int64
    var importedAt: Date
    var signedAt: Date?
    var certificateID: UUID?
    var originalBundleIdentifier: String?
    var sourceName: String?
    var presetID: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        version: String,
        build: String = "1",
        minimumOSVersion: String = "",
        fileName: String,
        iconFileName: String? = nil,
        byteSize: Int64 = 0,
        importedAt: Date = Date(),
        signedAt: Date? = nil,
        certificateID: UUID? = nil,
        originalBundleIdentifier: String? = nil,
        sourceName: String? = nil,
        presetID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.build = build
        self.minimumOSVersion = minimumOSVersion
        self.fileName = fileName
        self.iconFileName = iconFileName
        self.byteSize = byteSize
        self.importedAt = importedAt
        self.signedAt = signedAt
        self.certificateID = certificateID
        self.originalBundleIdentifier = originalBundleIdentifier
        self.sourceName = sourceName
        self.presetID = presetID
    }

    var isSigned: Bool { signedAt != nil }

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }

    var displayVersion: String {
        build.isEmpty || build == version ? version : "\(version) (\(build))"
    }
}
