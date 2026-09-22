import SwiftUI
import UniformTypeIdentifiers

struct TweaksLibraryView: View {
    @ObservedObject private var dylibStore = DylibLibraryStore.shared
    @State private var showingPicker = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if dylibStore.dylibs.isEmpty {
                VStack(spacing: SISpacing.md) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(SIColor.accent)
                    Text("No tweaks yet")
                        .font(SIFont.headline)
                    Text("Import a .dylib or .deb file to inject it into apps you sign.")
                        .font(SIFont.caption)
                        .foregroundStyle(SIColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SISpacing.xl)
                    Button("Import Tweak") { showingPicker = true }
                        .buttonStyle(.siPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(dylibStore.dylibs) { dylib in
                        HStack {
                            Image(systemName: "puzzlepiece.extension.fill")
                                .foregroundStyle(SIColor.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dylib.displayName).font(SIFont.headline)
                                Text(dylib.displaySize).font(SIFont.caption).foregroundStyle(SIColor.textSecondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { dylibStore.remove(dylibStore.dylibs[index]) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .siScreen()
        .navigationTitle("Tweak Library")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingPicker = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            DocumentPickerView(
                contentTypes: [.init(filenameExtension: "dylib") ?? .data, .init(filenameExtension: "deb") ?? .data],
                allowsMultipleSelection: true
            ) { urls in
                for url in urls {
                    do {
                        _ = try dylibStore.importFile(at: url)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        .alert("Import Failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
