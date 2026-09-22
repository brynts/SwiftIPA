import SwiftUI

struct SourcesView: View {
    @ObservedObject private var sourceStore = SourceStore.shared
    @State private var showingAddSheet = false

    var body: some View {
        Group {
            if sourceStore.sources.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sourceStore.sources) { source in
                        NavigationLink(value: source) {
                            SourceRow(source: source)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { sourceStore.removeSource(sourceStore.sources[index]) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .siScreen()
        .navigationTitle("Sources")
        .navigationDestination(for: RepositorySource.self) { source in
            SourceDetailView(sourceID: source.id)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddSourceSheet()
        }
    }

    private var emptyState: some View {
        VStack(spacing: SISpacing.md) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 48))
                .foregroundStyle(SIColor.accent)
            Text("No sources yet")
                .font(SIFont.headline)
            Text("Add an AltStore or ESign-compatible repo URL to browse and sign apps straight from it.")
                .font(SIFont.body)
                .foregroundStyle(SIColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SISpacing.xl)
            Button("Add Source") { showingAddSheet = true }
                .buttonStyle(.siPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SourceRow: View {
    let source: RepositorySource

    var body: some View {
        HStack(spacing: SISpacing.md) {
            AsyncImage(url: source.iconURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: SIRadius.sm, style: .continuous).fill(SIColor.surfaceElevated)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: SIRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name).font(SIFont.headline)
                Text(source.subtitle ?? source.url.host ?? "")
                    .font(SIFont.caption)
                    .foregroundStyle(SIColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(source.appCount)")
                .font(SIFont.caption)
                .foregroundStyle(SIColor.textSecondary)
        }
        .padding(.vertical, 4)
    }
}
