import SwiftUI

struct PresetsView: View {
    @ObservedObject private var presetStore = PresetStore.shared

    var body: some View {
        Group {
            if presetStore.presets.isEmpty {
                VStack(spacing: SISpacing.md) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 40))
                        .foregroundStyle(SIColor.accent)
                    Text("No presets yet")
                        .font(SIFont.headline)
                    Text("Save one from the signing sheet when you sign an app.")
                        .font(SIFont.caption)
                        .foregroundStyle(SIColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SISpacing.xl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(presetStore.presets) { preset in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name).font(SIFont.headline)
                            Text(preset.summary).font(SIFont.caption).foregroundStyle(SIColor.textSecondary)
                            if preset.useCount > 0 {
                                Text("Used \(preset.useCount) time(s)")
                                    .font(.caption2)
                                    .foregroundStyle(SIColor.textSecondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        for index in offsets { presetStore.delete(presetStore.presets[index]) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .siScreen()
        .navigationTitle("Presets")
    }
}
