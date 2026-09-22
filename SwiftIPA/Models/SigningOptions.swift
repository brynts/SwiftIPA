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

    var removePlugins: Bool = false
    var removeWatchApp: Bool = false
    var removeExtensions: Bool = false
    var removeLocalizations: Bool = false
    var removeDeviceRestrictions: Bool = true
    var removeURLSchemes: Bool = false
    var removeProvisioningProfile: Bool = false

    var forceFileSharing: Bool = false
    var forceProMotion: Bool = false
    var forceFullScreen: Bool = false
    var forceLocalNetworkAccess: Bool = false
    var allowArbitraryLoads: Bool = false

    var injectedDylibIDs: [UUID] = []
    var weakInjection: Bool = true
    var injectAtFront: Bool = false

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
        removePlugins || removeWatchApp || removeExtensions || removeLocalizations
            || removeURLSchemes || !injectedDylibIDs.isEmpty || customIconPath != nil
    }
}
