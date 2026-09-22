import SwiftUI
import UniformTypeIdentifiers

struct AddCertificateSheet: View {
    @State private var name = ""
    @State private var password = ""
    @State private var p12URL: URL?
    @State private var provisionURL: URL?
    @State private var showingP12Picker = false
    @State private var showingProvisionPicker = false
    @State private var isImporting = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Certificate Name")
                }

                Section {
                    filePickerRow(title: String(localized: "Certificate (.p12)"), selectedName: p12URL?.lastPathComponent) {
                        showingP12Picker = true
                    }
                    filePickerRow(title: String(localized: "Provisioning Profile (.mobileprovision)"), selectedName: provisionURL?.lastPathComponent) {
                        showingProvisionPicker = true
                    }
                    SecureField("P12 Password", text: $password)
                } header: {
                    Text("Files")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(SIColor.danger).font(SIFont.caption)
                    }
                }
            }
            .siScreen()
            .navigationTitle("Add Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addCertificate()
                    } label: {
                        if isImporting { ProgressView() } else { Text("Add") }
                    }
                    .disabled(!canAdd || isImporting)
                }
            }
            .sheet(isPresented: $showingP12Picker) {
                DocumentPickerView(contentTypes: [.init(filenameExtension: "p12") ?? .data], allowsMultipleSelection: false) { urls in
                    p12URL = urls.first
                }
            }
            .sheet(isPresented: $showingProvisionPicker) {
                DocumentPickerView(contentTypes: [.init(filenameExtension: "mobileprovision") ?? .data], allowsMultipleSelection: false) { urls in
                    provisionURL = urls.first
                }
            }
        }
    }

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && p12URL != nil && provisionURL != nil
    }

    private func filePickerRow(title: String, selectedName: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(SIColor.textPrimary)
                Spacer()
                Text(selectedName ?? String(localized: "Choose…"))
                    .foregroundStyle(SIColor.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private func addCertificate() {
        guard let p12URL, let provisionURL else { return }
        isImporting = true
        errorMessage = nil

        Task {
            do {
                _ = try CertificateStore.shared.addCertificate(
                    name: name,
                    p12SourceURL: p12URL,
                    provisionSourceURL: provisionURL,
                    password: password
                )
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
