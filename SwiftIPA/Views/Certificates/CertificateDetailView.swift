import SwiftUI

struct CertificateDetailView: View {
    let certificateID: UUID

    @ObservedObject private var certificateStore = CertificateStore.shared
    @State private var isRefreshing = false
    @Environment(\.dismiss) private var dismiss

    private var certificate: SigningCertificate? {
        certificateStore.certificates.first { $0.id == certificateID }
    }

    var body: some View {
        Group {
            if let certificate {
                List {
                    Section {
                        LabeledContent("Status") {
                            CertificateHealthBadge(health: certificate.health)
                        }
                        LabeledContent("Team", value: certificate.teamName ?? "—")
                        LabeledContent("Team ID", value: certificate.teamIdentifier ?? "—")
                        LabeledContent("Expires", value: certificate.displayExpiry)
                        if let days = certificate.daysRemaining {
                            LabeledContent("Days Remaining", value: "\(days)")
                        }
                        if let deviceCount = certificate.provisionedDeviceCount {
                            LabeledContent("Provisioned Devices", value: "\(deviceCount)")
                        }
                        LabeledContent("Unrestricted Entitlements", value: certificate.supportsUnrestrictedEntitlements ? String(localized: "Yes") : String(localized: "No"))
                    }

                    Section {
                        Button {
                            certificateStore.setDefault(certificate.id)
                        } label: {
                            Label("Set as Default", systemImage: "star.fill")
                        }
                        .disabled(certificateStore.defaultCertificateID == certificate.id)

                        Button {
                            refresh(certificate)
                        } label: {
                            if isRefreshing {
                                ProgressView()
                            } else {
                                Label("Re-check Expiry", systemImage: "arrow.clockwise")
                            }
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            certificateStore.removeCertificate(certificate)
                            dismiss()
                        } label: {
                            Label("Delete Certificate", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(certificate.name)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .siScreen()
    }

    private func refresh(_ certificate: SigningCertificate) {
        isRefreshing = true
        Task {
            await certificateStore.refreshHealth(for: certificate)
            await MainActor.run { isRefreshing = false }
        }
    }
}
