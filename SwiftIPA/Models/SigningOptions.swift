import Foundation

enum BundleIdentifierRule: String, Codable, CaseIterable, Identifiable {
    case keepOriginal
    case appendSuffix
    case randomSuffix
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .keepOriginal: return String(localized: "Keep original")
        case .appendSuffix: return String(localized: "Append suffix")
        case .randomSuffix: return String(localized: "Random suffix")
        case .custom: return String(localized: "Custom")
        }
    }
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return String(localized: "Automatic")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }

    var plistValue: String? {
        switch self {
        case .automatic: return nil
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum LiquidGlassMode: String, Codable, CaseIterable, Identifiable {
    case automatic
    case disabled
    case forced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return String(localized: "Automatic")
        case .disabled: return String(localized: "Disable Liquid Glass")
        case .forced: return String(localized: "Force Liquid Glass")
        }
    }
}

struct SigningOptions: Codable, Hashable {
    var displayName: String = ""
    var bundleIdentifier: String = ""
    var bundleIdentifierRule: BundleIdentifierRule = .keepOriginal
    var bundleIdentifierSuffix: String = ""
    var version: String = ""
    var build: String = ""
    var minimumOSVersion: String = ""
    var customIconPath: String?
    var entitlements: String?
    var appearance: AppAppearance = .automatic
    var liquidGlassMode: LiquidGlassMode = .automatic

    var removePlugins: Bool = false
    var removeWatchApp: Bool = false
    var removeLocalizations: Bool = false
    var removeDeviceRestrictions: Bool = true
    var removeURLSchemes: Bool = false
    var removeProvisioningProfile: Bool = false

    var forceFileSharing: Bool = false
    var forceDocumentBrowser: Bool = false
    var forceProMotion: Bool = false
    var forceFullScreen: Bool = false
    var forceGameMode: Bool = false
    var forceLocalNetworkAccess: Bool = false
    var allowArbitraryLoads: Bool = false
    var forceLocalizedDisplayName: Bool = false

    var injectedDylibIDs: [UUID] = []
    var weakInjection: Bool = true
    var injectAtFront: Bool = false
    var injectIntoExtensions: Bool = false

    var installAfterSigning: Bool = false
    var useCache: Bool = true
    var stripExistingSignature: Bool = true

    func resolvedBundleIdentifier(original: String) -> String {
        switch bundleIdentifierRule {
        case .keepOriginal:
            return original
        case .appendSuffix:
            let suffix = bundleIdentifierSuffix.trimmingCharacters(in: .whitespaces)
            return suffix.isEmpty ? original : "\(original).\(suffix)"
        case .randomSuffix:
            return "\(original).\(String(UUID().uuidString.prefix(6)).lowercased())"
        case .custom:
            let custom = bundleIdentifier.trimmingCharacters(in: .whitespaces)
            return custom.isEmpty ? original : custom
        }
    }

    var touchesBundleContents: Bool {
        removePlugins || removeWatchApp || removeLocalizations
            || removeURLSchemes || !injectedDylibIDs.isEmpty || customIconPath != nil
    }
}
