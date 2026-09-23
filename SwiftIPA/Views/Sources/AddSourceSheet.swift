import SwiftUI

struct AddSourceSheet: View {
    @State private var urlText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/repo.json", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isLoading)
                } header: {
                    Text("Repository URL")
                } footer: {
                    Text("Works with AltStore and ESign-format sources.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(SIColor.danger).font(SIFont.caption)
                    }
                }
            }
            .siScreen()
            .presentationDragIndicator(.visible)
            .navigationTitle("Add Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        add()
                    } label: {
                        if isLoading { ProgressView() } else { Text("Add") }
                    }
                    .disabled(URL(string: urlText) == nil || isLoading)
                }
            }
        }
    }

    private func add() {
        guard let url = URL(string: urlText) else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                _ = try await SourceStore.shared.addSource(url: url)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
