import SwiftUI
import Combine

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published private(set) var current: SITheme

    private let defaults = UserDefaults.standard
    private let key = "SwiftIPA.selectedTheme"

    private init() {
        if let raw = defaults.string(forKey: key), let id = SIThemeID(rawValue: raw) {
            current = SITheme.theme(for: id)
        } else {
            current = .orangeDark
        }
    }

    func select(_ id: SIThemeID) {
        current = SITheme.theme(for: id)
        defaults.set(id.rawValue, forKey: key)
    }
}
