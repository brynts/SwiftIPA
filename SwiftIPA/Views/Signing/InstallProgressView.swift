import SwiftUI

struct InstallProgressView: View {
    let entryID: UUID

    @State private var installURL: URL?
    @State private var errorMessage: String?
    @State private var isPreparing = true
    @State private var showingTrustSheet = false
    @State private var isUsingFallback = false

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
                        .padding(.horizontal, SISpacing.xl)
                    if !isUsingFallback {
                        Button("Try the Wi-Fi Method Instead") {
                            Task { await startServer(useFallback: true) }
                        }
                        .buttonStyle(.siPrimaryWide)
                        .padding(.horizontal, SISpacing.xl)
                    }
                } else if let installURL {
                    Image(systemName: "wifi")
                        .font(.system(size: 40))
                        .foregroundStyle(SIColor.accent)
                    Text("Ready to install.")
                        .font(SIFont.headline)
                    if isUsingFallback {
                        trustSteps
                    }
                    Button("Install Now") {
                        UIApplication.shared.open(installURL)
                    }
                    .buttonStyle(.siPrimaryWide)
                    .padding(.horizontal, SISpacing.xl)
                    if !isUsingFallback {
                        Button("Didn't Work? Try Wi-Fi Method") {
                            Task { await startServer(useFallback: true) }
                        }
                        .buttonStyle(.siSecondary)
                    }
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
                await startServer(useFallback: false)
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

    private func startServer(useFallback: Bool) async {
        guard let entry else { return }
        await MainActor.run {
            isPreparing = true
            errorMessage = nil
            installURL = nil
            isUsingFallback = useFallback
        }
        do {
            let url = try await InstallServer.shared.startInstall(
                ipaURL: AppLibraryStore.shared.ipaURL(for: entry),
                appName: entry.name,
                bundleIdentifier: entry.bundleIdentifier,
                version: entry.displayVersion,
                useSecureConnection: useFallback,
                useLocalNetworkAddress: useFallback
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
