import SwiftUI

private enum ResetAction: Identifiable, Equatable {
    case signedApps
    case importedApps
    case certificates
    case everything

    var id: Int {
        switch self {
        case .signedApps: return 0
        case .importedApps: return 1
        case .certificates: return 2
        case .everything: return 3
        }
    }

    var title: String {
        switch self {
        case .signedApps: return String(localized: "Remove all signed apps?")
        case .importedApps: return String(localized: "Remove all imported apps?")
        case .certificates: return String(localized: "Remove all certificates?")
        case .everything: return String(localized: "Reset SwiftIPA completely?")
        }
    }

    var message: String {
        switch self {
        case .signedApps: return String(localized: "This deletes every signed app from your library. Their original imported IPAs are removed too.")
        case .importedApps: return String(localized: "This deletes every app in your library that hasn't been signed yet. Signed apps are left alone.")
        case .certificates: return String(localized: "This deletes every certificate, its saved password, and its expiry tracking.")
        case .everything: return String(localized: "This deletes your entire library, all certificates, tweaks, presets, sources, and the signing cache, and resets every setting. There's no undo.")
        }
    }

    var confirmTitle: String {
        self == .everything ? String(localized: "Reset Everything") : String(localized: "Remove")
    }
}

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var certificateStore = CertificateStore.shared
    @State private var cacheSize: Int64 = SigningCache.shared.totalSize
    @State private var updateResult: UpdateCheckResult?
    @State private var isCheckingUpdate = false
    @State private var updateError: String?
    @State private var pendingReset: ResetAction?

    var body: some View {
        List {
            Section {
                ForEach(SIThemeID.allCases) { id in
                    Button {
                        themeManager.select(id)
                    } label: {
                        HStack {
                            Circle()
                                .fill(SITheme.theme(for: id).accent)
                                .frame(width: 18, height: 18)
                            Text(id.displayName)
                                .foregroundStyle(SIColor.textPrimary)
                            Spacer()
                            if themeManager.current.id == id {
                                Image(systemName: "checkmark").foregroundStyle(SIColor.accent)
                            }
                        }
                    }
                }
            } header: {
                Label("Appearance", systemImage: "paintpalette.fill")
            }

            Section {
                NavigationLink {
                    CertificatesView()
                } label: {
                    HStack {
                        Label("Certificates", systemImage: "checkmark.seal.fill")
                        Spacer()
                        Text("\(certificateStore.certificates.count)")
                            .foregroundStyle(SIColor.textSecondary)
                    }
                }
            } header: {
                Label("Signing Identity", systemImage: "signature")
            }

            Section {
                NavigationLink("Default Signing Options") { DefaultSigningOptionsView() }
                NavigationLink("Signing Presets") { PresetsView() }
                NavigationLink("Tweak Library") { TweaksLibraryView() }
                HStack {
                    Text("Instant-Resign Cache")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file))
                        .foregroundStyle(SIColor.textSecondary)
                }
                Button(role: .destructive) {
                    SigningCache.shared.clear()
                    cacheSize = 0
                } label: {
                    Text("Clear Cache")
                }
            } header: {
                Label("Signing", systemImage: "bolt.fill")
            }

            Section {
                Button {
                    exportCertificate()
                } label: {
                    Label("Export Trust Certificate", systemImage: "lock.doc")
                }
            } header: {
                Label("Local Install Server", systemImage: "wifi")
            }

            Section {
                NavigationLink("Changelog") { ChangelogView() }
                HStack {
                    Text("Version")
                    Spacer()
                    Text(versionString).foregroundStyle(SIColor.textSecondary)
                }
                Button {
                    checkForUpdate()
                } label: {
                    if isCheckingUpdate {
                        ProgressView()
                    } else {
                        Text("Check for Updates")
                    }
                }
                if let updateResult {
                    if updateResult.isUpdateAvailable {
                        Link("Update to \(updateResult.latestVersion) available", destination: updateResult.releaseURL)
                    } else {
                        Text("You're up to date.").foregroundStyle(SIColor.textSecondary)
                    }
                }
                if let updateError {
                    Text(updateError).foregroundStyle(SIColor.danger).font(SIFont.caption)
                }
                Link("Source on GitHub", destination: URL(string: "https://github.com/xsxs18-dev/SwiftIPA")!)
            } header: {
                Label("About", systemImage: "info.circle.fill")
            }

            Section {
                Button {
                    openAppFolder()
                } label: {
                    Label("View App Folder", systemImage: "folder.fill")
                }
            } header: {
                Label("Storage", systemImage: "internaldrive.fill")
            } footer: {
                Text("Opens SwiftIPA's Documents folder in the Files app — imported and signed IPAs, certificates, tweaks, and presets all live there.")
            }

            Section {
                Button(role: .destructive) {
                    pendingReset = .signedApps
                } label: {
                    Text("Remove All Signed Apps")
                }
                Button(role: .destructive) {
                    pendingReset = .importedApps
                } label: {
                    Text("Remove All Imported Apps")
                }
                Button(role: .destructive) {
                    pendingReset = .certificates
                } label: {
                    Text("Remove All Certificates")
                }
                Button(role: .destructive) {
                    pendingReset = .everything
                } label: {
                    Text("Reset Everything")
                }
            } header: {
                Label("Reset", systemImage: "trash.fill")
            } footer: {
                Text("These remove data from this device only and can't be undone.")
            }
        }
        .listStyle(.insetGrouped)
        .siScreen()
        .navigationTitle("Settings")
        .confirmationDialog(
            pendingReset?.title ?? "",
            isPresented: Binding(get: { pendingReset != nil }, set: { if !$0 { pendingReset = nil } }),
            titleVisibility: .visible
        ) {
            if let pendingReset {
                Button(pendingReset.confirmTitle, role: .destructive) {
                    performReset(pendingReset)
                }
            }
        } message: {
            if let pendingReset {
                Text(pendingReset.message)
            }
        }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func exportCertificate() {
        guard (try? LocalServerIdentity.exportTrustCertificate()) != nil else { return }
    }

    private func openAppFolder() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let url = URL(string: "shareddocuments://" + documents.path) else { return }
        UIApplication.shared.open(url)
    }

    private func performReset(_ action: ResetAction) {
        switch action {
        case .signedApps:
            AppLibraryStore.shared.removeAll { $0.isSigned }
        case .importedApps:
            AppLibraryStore.shared.removeAll { !$0.isSigned }
        case .certificates:
            certificateStore.removeAllCertificates()
        case .everything:
            AppLibraryStore.shared.removeAll { _ in true }
            certificateStore.removeAllCertificates()
            DylibLibraryStore.shared.removeAll()
            PresetStore.shared.removeAll()
            SourceStore.shared.removeAll()
            DefaultSigningOptionsStore.shared.resetToDefaults()
            SigningCache.shared.clear()
            cacheSize = 0
        }
    }

    private func checkForUpdate() {
        isCheckingUpdate = true
        updateError = nil
        Task {
            do {
                let result = try await UpdateChecker.shared.checkForUpdate()
                await MainActor.run {
                    updateResult = result
                    isCheckingUpdate = false
                }
            } catch {
                await MainActor.run {
                    updateError = error.localizedDescription
                    isCheckingUpdate = false
                }
            }
        }
    }
}
