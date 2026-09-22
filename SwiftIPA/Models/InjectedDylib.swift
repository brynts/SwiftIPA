import Foundation

struct InjectedDylib: Identifiable, Codable, Hashable {
    let id: UUID
    var fileName: String
    var displayName: String
    var isWeak: Bool
    var addedAt: Date
    var byteSize: Int64

    init(
        id: UUID = UUID(),
        fileName: String,
        displayName: String,
        isWeak: Bool = true,
        addedAt: Date = Date(),
        byteSize: Int64 = 0
    ) {
        self.id = id
        self.fileName = fileName
        self.displayName = displayName
        self.isWeak = isWeak
        self.addedAt = addedAt
        self.byteSize = byteSize
    }

    var isDebPackage: Bool {
        fileName.lowercased().hasSuffix(".deb")
    }

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }
}
