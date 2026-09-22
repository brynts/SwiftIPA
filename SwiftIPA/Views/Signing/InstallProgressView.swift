import SwiftUI

struct InstallProgressView: View {
    let entryID: UUID

    @State private var installURL: URL?
    @State private var errorMessage: String?
    @State private var isPreparing = true
    @State private var showingTrustSheet = false

    @Environment(\.dismiss) private var dismiss

    private var entry: AppEntry? {
        AppLibraryStore.shared.apps.first { $0.id == entryID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SISpacing.lg) {
                if isPreparing {
                    ProgressView("Starting local server…")
                } else if let errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(SIColor.danger)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(SIColor.textSecondary)
                    Button("Trust SwiftIPA's Local Certificate") { showingTrustSheet = true }
                        .buttonStyle(.siSecondary)
                } else if let installURL {
                    Image(systemName: "wifi")
                        .font(.system(size: 40))
                        .foregroundStyle(SIColor.accent)
                    Text("Ready to install over your local network.")
                        .font(SIFont.headline)
                    Text("The first time you do this, iOS will ask you to trust SwiftIPA's local certificate in Settings → General → VPN & Device Management.")
                        .font(SIFont.caption)
                        .foregroundStyle(SIColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SISpacing.xl)
                    Button("Install Now") {
                        UIApplication.shared.open(installURL)
                    }
                    .buttonStyle(.siPrimaryWide)
                    .padding(.horizontal, SISpacing.xl)
                    Button("Trust Local Certificate") { showingTrustSheet = true }
                        .buttonStyle(.siSecondary)
                }
            }
            .padding()
            .siScreen()
            .navigationTitle("Install")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        InstallServer.shared.stop()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingTrustSheet) {
                if let certURL = try? LocalServerIdentity.exportTrustCertificate() {
                    ShareSheet(items: [certURL])
                }
            }
            .task {
                await startServer()
            }
        }
    }

    private func startServer() async {
        guard let entry else { return }
        do {
            let url = try await InstallServer.shared.startInstall(
                ipaURL: AppLibraryStore.shared.ipaURL(for: entry),
                appName: entry.name,
                bundleIdentifier: entry.bundleIdentifier,
                version: entry.displayVersion
            )
            await MainActor.run {
                installURL = url
                isPreparing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isPreparing = false
            }
        }
    }
}
