import Foundation

struct UpdateCheckResult {
    let isUpdateAvailable: Bool
    let currentVersion: String
    let latestVersion: String
    let releaseURL: URL
}

enum UpdateCheckError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return String(localized: "Could not check for updates.")
        }
    }
}

struct ChangelogEntry: Decodable, Identifiable {
    let tag_name: String
    let name: String?
    let body: String?
    let published_at: String?

    var id: String { tag_name }

    var displayVersion: String {
        guard let name, name.hasPrefix("SwiftIPA ") else {
            return name ?? tag_name
        }
        let remainder = name.dropFirst("SwiftIPA ".count)
        if let spaceIndex = remainder.firstIndex(of: " ") {
            return String(remainder[..<spaceIndex])
        }
        return String(remainder)
    }

    var displayBuild: String? {
        guard let name, let openParen = name.firstIndex(of: "("), let closeParen = name.lastIndex(of: ")") else { return nil }
        return String(name[name.index(after: openParen)..<closeParen])
    }

    var displayChanges: String {
        guard let body else { return "" }
        if let range = body.range(of: "### Changes\n") {
            return String(body[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayDate: String? {
        guard let published_at, let date = ISO8601DateFormatter().date(from: published_at) else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

final class UpdateChecker {
    static let shared = UpdateChecker()
    private let repo = "xsxs18-dev/SwiftIPA"

    func checkForUpdate() async throws -> UpdateCheckResult {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UpdateCheckError.invalidResponse
        }
        let entry = try JSONDecoder().decode(ChangelogEntry.self, from: data)
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let latest = entry.displayVersion
        let releaseURL = URL(string: "https://github.com/\(repo)/releases/tag/\(entry.tag_name)")!
        return UpdateCheckResult(
            isUpdateAvailable: latest.compare(current, options: .numeric) == .orderedDescending,
            currentVersion: current,
            latestVersion: latest,
            releaseURL: releaseURL
        )
    }

    func fetchChangelog() async throws -> [ChangelogEntry] {
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UpdateCheckError.invalidResponse
        }
        return try JSONDecoder().decode([ChangelogEntry].self, from: data)
    }
}
