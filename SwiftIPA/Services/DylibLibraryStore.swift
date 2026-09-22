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
    func importFile(at sourceURL: URL, displayName: String? = nil) throws -> InjectedDylib {
        let fileManager = FileManager.default
        let needsAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        if sourceURL.pathExtension.lowercased() == "deb" {
            let extracted = try DebExtractor.extractDylibs(from: sourceURL, into: folder)
            guard let first = extracted.first else { throw DebExtractorError.noDylibFound }
            return try registerImportedFile(at: first, displayName: displayName ?? sourceURL.deletingPathExtension().lastPathComponent)
        }

        let destinationName = uniqueFileName(for: sourceURL.lastPathComponent)
        let destination = folder.appendingPathComponent(destinationName)
        try fileManager.copyItem(at: sourceURL, to: destination)
        return try registerImportedFile(at: destination, displayName: displayName ?? sourceURL.deletingPathExtension().lastPathComponent)
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

    private func registerImportedFile(at fileURL: URL, displayName: String) throws -> InjectedDylib {
        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        let entry = InjectedDylib(fileName: fileURL.lastPathComponent, displayName: displayName, byteSize: size)
        dylibs.append(entry)
        persist()
        return entry
    }

    private func uniqueFileName(for name: String) -> String {
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
