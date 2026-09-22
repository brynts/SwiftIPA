import Foundation

enum InfoPlistPatcher {
    static func read(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    static func apply(_ options: SigningOptions, toPlistAt url: URL) throws {
        guard var plist = read(at: url) else { return }
        var changed = false

        if options.forceFileSharing {
            plist["UIFileSharingEnabled"] = true
            plist["LSSupportsOpeningDocumentsInPlace"] = true
            changed = true
        }
        if options.forceFullScreen {
            plist["UIRequiresFullScreen"] = true
            changed = true
        }
        if options.forceProMotion {
            plist["CADisableMinimumFrameDurationOnPhone"] = true
            changed = true
        }
        if options.removeURLSchemes {
            plist.removeValue(forKey: "CFBundleURLTypes")
            changed = true
        }
        if options.allowArbitraryLoads {
            var transport = plist["NSAppTransportSecurity"] as? [String: Any] ?? [:]
            transport["NSAllowsArbitraryLoads"] = true
            plist["NSAppTransportSecurity"] = transport
            changed = true
        }
        if options.removeDeviceRestrictions {
            plist.removeValue(forKey: "UIRequiredDeviceCapabilities")
            changed = true
        }

        guard changed else { return }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        try data.write(to: url, options: .atomic)
    }

    static func removeLocalizations(inAppFolder appFolder: URL, keeping preferredLanguages: Set<String> = ["en", "Base"]) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: appFolder, includingPropertiesForKeys: nil) else { return }
        for item in contents where item.pathExtension == "lproj" {
            let name = item.deletingPathExtension().lastPathComponent
            guard !preferredLanguages.contains(name) else { continue }
            try? fileManager.removeItem(at: item)
        }
    }
}
