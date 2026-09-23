import SwiftUI

struct InstallProgressView: View {
    let entryID: UUID

    @State private var installURL: URL?
    @State private var errorMessage: String?
    @State private var isPreparing = true
    @State private var showingTrustSheet = false
    @State private var hasTrustedCertificate = UserDefaults.standard.bool(forKey: "SwiftIPA.hasTrustedLocalCertificate")

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
                    trustSteps
                } else if !hasTrustedCertificate {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(SIColor.accent)
                    Text("One-time setup")
                        .font(SIFont.headline)
                    Text("Before your first direct install, iOS needs to trust SwiftIPA's local certificate. Do this once — every install after is a single tap.")
                        .font(SIFont.caption)
                        .foregroundStyle(SIColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SISpacing.xl)
                    trustSteps
                    Button("I've Trusted It — Continue") {
                        hasTrustedCertificate = true
                        UserDefaults.standard.set(true, forKey: "SwiftIPA.hasTrustedLocalCertificate")
                    }
                    .buttonStyle(.siPrimaryWide)
                    .padding(.horizontal, SISpacing.xl)
                } else if let installURL {
                    Image(systemName: "wifi")
                        .font(.system(size: 40))
                        .foregroundStyle(SIColor.accent)
                    Text("Ready to install over your local network.")
                        .font(SIFont.headline)
                    Button("Install Now") {
                        UIApplication.shared.open(installURL)
                    }
                    .buttonStyle(.siPrimaryWide)
                    .padding(.horizontal, SISpacing.xl)
                    Button("Trust Certificate Again") { showingTrustSheet = true }
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

    private var trustSteps: some View {
        VStack(alignment: .leading, spacing: SISpacing.sm) {
            trustStep(number: 1, text: String(localized: "Tap \"Trust Local Certificate\" below and save the file to Files."))
            trustStep(number: 2, text: String(localized: "Open the saved file — iOS will offer to install a profile."))
            trustStep(number: 3, text: String(localized: "Settings → General → VPN & Device Management → SwiftIPA Local Server → Trust."))
            Button("Trust Local Certificate") { showingTrustSheet = true }
                .buttonStyle(.siSecondary)
                .padding(.top, SISpacing.xs)
        }
        .padding(SISpacing.md)
        .siCard()
        .padding(.horizontal, SISpacing.md)
    }

    private func trustStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: SISpacing.sm) {
            Text("\(number)")
                .font(SIFont.caption.bold())
                .foregroundStyle(Color.black)
                .frame(width: 20, height: 20)
                .background(SIColor.accent)
                .clipShape(Circle())
            Text(text)
                .font(SIFont.caption)
                .foregroundStyle(SIColor.textSecondary)
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
