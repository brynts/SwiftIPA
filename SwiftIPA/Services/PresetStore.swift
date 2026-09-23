import Foundation
import Combine

final class PresetStore: ObservableObject {
    static let shared = PresetStore()

    @Published private(set) var presets: [SigningPreset] = []

    private let defaults = UserDefaults.standard
    private let key = "SwiftIPA.signingPresets"

    private init() {
        presets = load()
    }

    @discardableResult
    func save(name: String, certificateID: UUID?, options: SigningOptions) -> SigningPreset {
        let preset = SigningPreset(name: name, certificateID: certificateID, options: options)
        presets.append(preset)
        persist()
        return preset
    }

    func delete(_ preset: SigningPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    func removeAll() {
        presets.removeAll()
        persist()
    }

    func markUsed(_ preset: SigningPreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].lastUsedAt = Date()
        presets[index].useCount += 1
        persist()
    }

    private func load() -> [SigningPreset] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SigningPreset].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: key)
    }
}
