import SwiftUI

struct InstallProgressView: View {
    let entryID: UUID

    @State private var installLink: InstallLink?
    @State private var errorMessage: String?
    @State private var isPreparing = true
    @State private var showingTrustSheet = false
    @State private var isUsingFallback = false
    @State private var isUsingLoopback = false
    @State private var showingSafari = false

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
                        if !isUsingLoopback {
                            Button("Try Localhost Instead") {
                                Task { await startServer(useFallback: false, useLoopback: true) }
                            }
                            .buttonStyle(.siPrimaryWide)
                            .padding(.horizontal, SISpacing.xl)
                        }
                        Button("Try the Certificate Method Instead") {
                            Task { await startServer(useFallback: true, useLoopback: false) }
                        }
                        .buttonStyle(.siSecondary)
                        .padding(.horizontal, SISpacing.xl)
                    }
                } else if let installLink {
                    Image(systemName: "wifi")
                        .font(.system(size: 40))
                        .foregroundStyle(SIColor.accent)
                    Text("Ready to install.")
                        .font(SIFont.headline)
                    if isUsingFallback {
                        trustSteps
                    } else {
                        Text("No certificate, no profile — this uses a small public relay just to hand iOS a properly hosted install manifest. Your IPA itself never leaves your device.")
                            .font(SIFont.caption)
                            .foregroundStyle(SIColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SISpacing.xl)
                    }
                    Button("Install Now") {
                        switch installLink.presentationStyle {
                        case .direct:
                            UIApplication.shared.open(installLink.url)
                        case .webView:
                            showingSafari = true
                        }
                    }
                    .buttonStyle(.siPrimaryWide)
                    .padding(.horizontal, SISpacing.xl)
                    if isUsingFallback {
                        Button("Try Without a Certificate Instead") {
                            Task { await startServer(useFallback: false, useLoopback: false) }
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
            .fullScreenCover(isPresented: $showingSafari) {
                if let installLink {
                    SafariView(url: installLink.url)
                        .ignoresSafeArea()
                }
            }
            .task {
                await startServer(useFallback: false, useLoopback: false)
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

    private func startServer(useFallback: Bool, useLoopback: Bool) async {
        guard let entry else { return }
        await MainActor.run {
            isPreparing = true
            errorMessage = nil
            installLink = nil
            isUsingFallback = useFallback
            isUsingLoopback = useLoopback
        }
        do {
            let link = try await InstallServer.shared.startInstall(
                ipaURL: AppLibraryStore.shared.ipaURL(for: entry),
                appName: entry.name,
                bundleIdentifier: entry.bundleIdentifier,
                version: entry.displayVersion,
                mode: useFallback ? .secureDirect : .externalManifest,
                preferLoopback: useLoopback
            )
            await MainActor.run {
                installLink = link
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
