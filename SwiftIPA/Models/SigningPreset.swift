import Foundation

struct SigningPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var certificateID: UUID?
    var options: SigningOptions
    var createdAt: Date
    var lastUsedAt: Date?
    var useCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        certificateID: UUID? = nil,
        options: SigningOptions = SigningOptions(),
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        useCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.certificateID = certificateID
        self.options = options
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
    }

    var summary: String {
        var parts: [String] = []
        parts.append(options.bundleIdentifierRule.displayName)
        if !options.injectedDylibIDs.isEmpty {
            parts.append(String(localized: "\(options.injectedDylibIDs.count) tweak(s)"))
        }
        if options.removePlugins { parts.append(String(localized: "no plug-ins")) }
        if options.removeWatchApp { parts.append(String(localized: "no watch app")) }
        return parts.joined(separator: " · ")
    }
}
