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

    static func download(_ version: RepositoryAppVersion, progress: @escaping (Double?, Int64) -> Void) async throws -> URL {
        let downloader = ProgressReportingDownloader(onProgress: progress)
        return try await downloader.download(from: version.downloadURL)
    }
}
