import SwiftUI

struct EntitlementsEditorView: View {
    @Binding var text: String
    let certificateID: UUID?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(SIFont.mono)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(SISpacing.sm)
                .siScreen()
                .navigationTitle("Entitlements")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Reset to Certificate Default") { loadDefault() }
                            .font(.caption)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    private func loadDefault() {
        guard let certificateID, let certificate = CertificateStore.shared.certificate(withID: certificateID) else { return }
        guard let info = try? CertificateService.inspectProvisioningProfile(at: CertificateStore.shared.provisionURL(for: certificate)) else { return }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: info.entitlements, format: .xml, options: 0) else { return }
        text = String(data: data, encoding: .utf8) ?? text
    }
}
