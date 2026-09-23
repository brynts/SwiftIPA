import SwiftUI

struct DownloadByURLSheet: View {
    @State private var urlText = ""
    @State private var isDownloading = false
    @State private var progress: Double?
    @State private var downloadedBytes: Int64 = 0
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/app.ipa", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isDownloading)
                } header: {
                    Text("IPA URL")
                }

                if isDownloading {
                    Section {
                        if let progress {
                            ProgressView(value: progress)
                            Text("\(Int(progress * 100))%")
                                .font(SIFont.caption)
                                .foregroundStyle(SIColor.textSecondary)
                        } else {
                            ProgressView()
                            Text(byteFormatter.string(fromByteCount: downloadedBytes))
                                .font(SIFont.caption)
                                .foregroundStyle(SIColor.textSecondary)
                        }
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
                        .disabled(URL(string: urlText) == nil || isDownloading)
                }
            }
        }
    }

    private func startDownload() {
        guard let url = URL(string: urlText) else { return }
        isDownloading = true
        progress = 0
        downloadedBytes = 0
        errorMessage = nil

        Task {
            do {
                let downloader = ProgressReportingDownloader { fraction, bytesWritten in
                    Task { @MainActor in
                        progress = fraction
                        downloadedBytes = bytesWritten
                    }
                }
                let downloaded = try await downloader.download(from: url)
                defer { try? FileManager.default.removeItem(at: downloaded) }

                _ = try await AppLibraryStore.shared.importIPA(at: downloaded, sourceName: url.host)

                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    progress = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private final class ProgressReportingDownloader: NSObject, URLSessionDownloadDelegate {
    private var continuation: CheckedContinuation<URL, Error>?
    private let onProgress: (Double?, Int64) -> Void
    private var session: URLSession?

    init(onProgress: @escaping (Double?, Int64) -> Void) {
        self.onProgress = onProgress
    }

    func download(from url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            self.session = session
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let fraction = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : nil
        onProgress(fraction, totalBytesWritten)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let httpResponse = downloadTask.response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            continuation?.resume(throwing: RepositoryServiceError.invalidResponse)
            continuation = nil
            return
        }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).ipa")
        do {
            try FileManager.default.replaceItem(at: destination, withItemAt: location)
            continuation?.resume(returning: destination)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
