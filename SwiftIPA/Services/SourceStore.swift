import Foundation
import Combine
import SwiftUI

final class SourceStore: ObservableObject {
    static let shared = SourceStore()

    @Published private(set) var sources: [RepositorySource] = []
    @Published private(set) var catalog: [UUID: [RepositoryApp]] = [:]

    private let defaults = UserDefaults.standard
    private let key = "SwiftIPA.repositorySources"

    private init() {
        sources = load()
    }

    @discardableResult
    func addSource(url: URL) async throws -> RepositorySource {
        let payload = try await RepositoryService.fetch(url: url)
        let source = RepositorySource(
            url: url,
            name: payload.name ?? url.host ?? url.absoluteString,
            subtitle: payload.subtitle ?? payload.description,
            iconURL: payload.iconURL,
            lastRefreshedAt: Date(),
            appCount: payload.apps.count
        )
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.25)) {
                sources.append(source)
            }
            catalog[source.id] = payload.apps
            persist()
        }
        return source
    }

    func removeSource(_ source: RepositorySource) {
        withAnimation(.easeOut(duration: 0.25)) {
            sources.removeAll { $0.id == source.id }
        }
        catalog.removeValue(forKey: source.id)
        persist()
    }

    func removeAll() {
        withAnimation(.easeOut(duration: 0.25)) {
            sources.removeAll()
        }
        catalog.removeAll()
        persist()
    }

    func refresh(_ source: RepositorySource) async {
        guard let payload = try? await RepositoryService.fetch(url: source.url) else { return }
        await MainActor.run {
            guard let index = sources.firstIndex(where: { $0.id == source.id }) else { return }
            sources[index].lastRefreshedAt = Date()
            sources[index].appCount = payload.apps.count
            catalog[source.id] = payload.apps
            persist()
        }
    }

    func apps(for source: RepositorySource) -> [RepositoryApp] {
        catalog[source.id] ?? []
    }

    private func load() -> [RepositorySource] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RepositorySource].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        defaults.set(data, forKey: key)
    }
}
