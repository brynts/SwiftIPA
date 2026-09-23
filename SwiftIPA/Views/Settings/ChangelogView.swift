import SwiftUI

struct ChangelogView: View {
    @State private var entries: [ChangelogEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: SISpacing.sm) {
                    Text(errorMessage).foregroundStyle(SIColor.textSecondary)
                    Button("Try Again") { load() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 6) {
                                Text(entry.displayVersion).font(SIFont.headline)
                                if let build = entry.displayBuild {
                                    Text(build).font(SIFont.caption).foregroundStyle(SIColor.textSecondary)
                                }
                            }
                            Spacer()
                            if let date = entry.displayDate {
                                Text(date).font(SIFont.caption).foregroundStyle(SIColor.textSecondary)
                            }
                        }
                        Text(entry.displayChanges).font(SIFont.body)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .siScreen()
        .navigationTitle("Changelog")
        .onAppear(perform: load)
    }

    private func load() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await UpdateChecker.shared.fetchChangelog()
                await MainActor.run {
                    entries = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
