import Foundation

enum SigningJobStatus: Equatable {
    case queued
    case extracting
    case patching
    case signing
    case packaging
    case cached
    case done(TimeInterval)
    case failed(String)
}

final class SigningJob: Identifiable, ObservableObject {
    let id = UUID()
    let appEntryID: UUID
    let sourceIPAURL: URL
    let displayName: String
    var options: SigningOptions
    let certificateID: UUID

    @Published var status: SigningJobStatus = .queued

    init(appEntryID: UUID, sourceIPAURL: URL, displayName: String, options: SigningOptions, certificateID: UUID) {
        self.appEntryID = appEntryID
        self.sourceIPAURL = sourceIPAURL
        self.displayName = displayName
        self.options = options
        self.certificateID = certificateID
    }
}
