import SwiftUI

struct DownloadByURLSheet: View {
    @State private var urlText = ""
    @State private var progress: Double?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/app.ipa", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(progress != nil)
                } header: {
                    Text("IPA URL")
                }

                if let progress {
                    Section {
                        ProgressView(value: progress)
                        Text("\(Int(progress * 100))%")
                            .font(SIFont.caption)
                            .foregroundStyle(SIColor.textSecondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(SIColor.danger)
                            .font(SIFont.caption)
                    }
                }
            }
            .siScreen()
            .navigationTitle("Download IPA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Download") { startDownload() }
                        .disabled(URL(string: urlText) == nil || progress != nil)
                }
            }
        }
    }

    private func startDownload() {
        guard let url = URL(string: urlText) else { return }
        progress = 0
        errorMessage = nil

        Task {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw RepositoryServiceError.invalidResponse
                }
                let expected = httpResponse.expectedContentLength
                let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).ipa")
                FileManager.default.createFile(atPath: destination.path, contents: nil)
                let handle = try FileHandle(forWritingTo: destination)

                var received: Int64 = 0
                var buffer = Data()
                for try await byte in bytes {
                    buffer.append(byte)
                    if buffer.count >= 262_144 {
                        handle.write(buffer)
                        received += Int64(buffer.count)
                        buffer.removeAll(keepingCapacity: true)
                        if expected > 0 {
                            let value = Double(received) / Double(expected)
                            await MainActor.run { progress = value }
                        }
                    }
                }
                if !buffer.isEmpty { handle.write(buffer) }
                try? handle.close()

                _ = try AppLibraryStore.shared.importIPA(at: destination, sourceName: url.host)
                try? FileManager.default.removeItem(at: destination)

                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    progress = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
