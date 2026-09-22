import Foundation
import Combine

final class DylibLibraryStore: ObservableObject {
    static let shared = DylibLibraryStore()

    @Published private(set) var dylibs: [InjectedDylib] = []

    private let folder: URL
    private let indexURL: URL

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = documents.appendingPathComponent("Tweaks", isDirectory: true)
        indexURL = documents.appendingPathComponent("tweaks-index.json")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        dylibs = load()
    }

    func url(for dylib: InjectedDylib) -> URL {
        folder.appendingPathComponent(dylib.fileName)
    }

    @discardableResult
    func importFile(at sourceURL: URL, displayName: String? = nil) async throws -> InjectedDylib {
        let folder = folder
        let resolvedDisplayName = displayName ?? sourceURL.deletingPathExtension().lastPathComponent

        let importedURL = try await Task.detached(priority: .userInitiated) { () -> URL in
            let fileManager = FileManager.default
            let needsAccess = sourceURL.startAccessingSecurityScopedResource()
            defer { if needsAccess { sourceURL.stopAccessingSecurityScopedResource() } }

            if sourceURL.pathExtension.lowercased() == "deb" {
                let extracted = try DebExtractor.extractDylibs(from: sourceURL, into: folder)
                guard let first = extracted.first else { throw DebExtractorError.noDylibFound }
                return first
            }

            let destinationName = Self.uniqueFileName(for: sourceURL.lastPathComponent, in: folder)
            let destination = folder.appendingPathComponent(destinationName)
            try fileManager.copyItem(at: sourceURL, to: destination)
            return destination
        }.value

        let size = (try? FileManager.default.attributesOfItem(atPath: importedURL.path)[.size] as? Int64) ?? 0
        let entry = InjectedDylib(fileName: importedURL.lastPathComponent, displayName: resolvedDisplayName, byteSize: size)

        await MainActor.run {
            dylibs.append(entry)
            persist()
        }
        return entry
    }

    func remove(_ dylib: InjectedDylib) {
        try? FileManager.default.removeItem(at: url(for: dylib))
        dylibs.removeAll { $0.id == dylib.id }
        persist()
    }

    func rename(_ dylib: InjectedDylib, to newDisplayName: String) {
        guard let index = dylibs.firstIndex(where: { $0.id == dylib.id }) else { return }
        dylibs[index].displayName = newDisplayName
        persist()
    }

    private static func uniqueFileName(for name: String, in folder: URL) -> String {
        var candidate = name
        var attempt = 1
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            let stem = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
            candidate = "\(stem)-\(attempt).\(ext)"
            attempt += 1
        }
        return candidate
    }

    private func load() -> [InjectedDylib] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder().decode([InjectedDylib].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(dylibs) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
