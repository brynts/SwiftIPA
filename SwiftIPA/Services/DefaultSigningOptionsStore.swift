import Foundation
import Combine

final class DefaultSigningOptionsStore: ObservableObject {
    static let shared = DefaultSigningOptionsStore()

    @Published var options: SigningOptions

    private let defaults = UserDefaults.standard
    private let key = "SwiftIPA.defaultSigningOptions"

    private init() {
        if let data = defaults.data(forKey: key), let decoded = try? JSONDecoder().decode(SigningOptions.self, from: data) {
            options = decoded
        } else {
            options = SigningOptions()
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(options) else { return }
        defaults.set(data, forKey: key)
    }

    func resetToDefaults() {
        options = SigningOptions()
        save()
    }

    func makeOptions(seededWith entry: AppEntry) -> SigningOptions {
        var seeded = options
        seeded.displayName = entry.name
        seeded.version = entry.version
        seeded.build = entry.build
        if seeded.minimumOSVersion.isEmpty {
            seeded.minimumOSVersion = entry.minimumOSVersion
        }
        return seeded
    }
}
