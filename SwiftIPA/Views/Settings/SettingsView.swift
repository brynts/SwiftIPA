import SwiftUI

struct SettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var certificateStore = CertificateStore.shared
    @State private var cacheSize: Int64 = SigningCache.shared.totalSize
    @State private var updateResult: UpdateCheckResult?
    @State private var isCheckingUpdate = false
    @State private var updateError: String?

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
        }
        .listStyle(.insetGrouped)
        .siScreen()
        .navigationTitle("Settings")
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func exportCertificate() {
        guard (try? LocalServerIdentity.exportTrustCertificate()) != nil else { return }
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
