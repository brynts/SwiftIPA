import Foundation

struct RepositorySource: Identifiable, Codable, Hashable {
    let id: UUID
    var url: URL
    var name: String
    var subtitle: String?
    var iconURL: URL?
    var addedAt: Date
    var lastRefreshedAt: Date?
    var appCount: Int

    init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        subtitle: String? = nil,
        iconURL: URL? = nil,
        addedAt: Date = Date(),
        lastRefreshedAt: Date? = nil,
        appCount: Int = 0
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.subtitle = subtitle
        self.iconURL = iconURL
        self.addedAt = addedAt
        self.lastRefreshedAt = lastRefreshedAt
        self.appCount = appCount
    }
}

struct RepositoryPayload: Decodable {
    let name: String?
    let identifier: String?
    let subtitle: String?
    let description: String?
    let iconURL: URL?
    let headerURL: URL?
    let website: URL?
    let apps: [RepositoryApp]

    private enum CodingKeys: String, CodingKey {
        case name, identifier, subtitle, description, iconURL, headerURL, website, apps
        case sourceiconURL, sourceicon, icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        let primaryIcon = try container.decodeIfPresent(URL.self, forKey: .iconURL)
        let altIcon = try container.decodeIfPresent(URL.self, forKey: .sourceiconURL)
        let legacyIcon = try container.decodeIfPresent(URL.self, forKey: .sourceicon)
        let plainIcon = try container.decodeIfPresent(URL.self, forKey: .icon)
        iconURL = primaryIcon ?? altIcon ?? legacyIcon ?? plainIcon
        headerURL = try container.decodeIfPresent(URL.self, forKey: .headerURL)
        website = try container.decodeIfPresent(URL.self, forKey: .website)
        apps = (try? container.decode([RepositoryApp].self, forKey: .apps)) ?? []
    }
}

struct RepositoryApp: Decodable, Identifiable, Hashable {
    let name: String
    let bundleIdentifier: String
    let developerName: String?
    let subtitle: String?
    let localizedDescription: String?
    let iconURL: URL?
    let versions: [RepositoryAppVersion]

    var id: String { bundleIdentifier + (versions.first?.version ?? name) }

    var latest: RepositoryAppVersion? { versions.first }

    private enum CodingKeys: String, CodingKey {
        case name, bundleIdentifier, developerName, subtitle, localizedDescription
        case iconURL, icon, versions, version, downloadURL, size, versionDate
        case minOSVersion, versionDescription, absoluteVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? String(localized: "Untitled app")
        bundleIdentifier = (try? container.decode(String.self, forKey: .bundleIdentifier)) ?? ""
        developerName = try? container.decodeIfPresent(String.self, forKey: .developerName)
        subtitle = try? container.decodeIfPresent(String.self, forKey: .subtitle)
        localizedDescription = try? container.decodeIfPresent(String.self, forKey: .localizedDescription)
        let primaryIcon = try? container.decodeIfPresent(URL.self, forKey: .iconURL)
        let plainIcon = try? container.decodeIfPresent(URL.self, forKey: .icon)
        iconURL = (primaryIcon ?? nil) ?? (plainIcon ?? nil)

        if let parsed = try? container.decode([RepositoryAppVersion].self, forKey: .versions), !parsed.isEmpty {
            versions = parsed
        } else if let download = try? container.decode(URL.self, forKey: .downloadURL) {
            let single = RepositoryAppVersion(
                version: (try? container.decode(String.self, forKey: .version)) ?? "1.0",
                date: try? container.decodeIfPresent(String.self, forKey: .versionDate),
                localizedDescription: try? container.decodeIfPresent(String.self, forKey: .versionDescription),
                downloadURL: download,
                size: (try? container.decodeIfPresent(Int64.self, forKey: .size)) ?? nil,
                minOSVersion: try? container.decodeIfPresent(String.self, forKey: .minOSVersion)
            )
            versions = [single]
        } else {
            versions = []
        }
    }
}

struct RepositoryAppVersion: Decodable, Hashable {
    let version: String
    let date: String?
    let localizedDescription: String?
    let downloadURL: URL
    let size: Int64?
    let minOSVersion: String?

    var displaySize: String? {
        guard let size else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var displayDate: String? {
        guard let date else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsed = iso.date(from: date) ?? ISO8601DateFormatter().date(from: date)
        guard let parsed else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: parsed)
    }
}
