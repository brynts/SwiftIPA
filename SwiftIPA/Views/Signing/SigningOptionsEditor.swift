import SwiftUI

struct SigningOptionsEditor: View {
    @Binding var options: SigningOptions
    var certificateID: UUID?
    var showsInstallToggle: Bool = true

    @ObservedObject private var dylibStore = DylibLibraryStore.shared

    var body: some View {
        appearanceSection
        compatibilitySection
        removalSection
        networkSection
        tweaksSection
        entitlementsSection
        advancedSection
    }

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $options.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.displayName).tag(appearance)
                }
            }
            Picker("Design", selection: $options.liquidGlassMode) {
                ForEach(LiquidGlassMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        } header: {
            Label("Appearance", systemImage: "paintpalette.fill")
        } footer: {
            Text("Design forces an app to use, or not use, iOS 26's Liquid Glass redesign. Not every app supports being switched either way.")
        }
    }

    private var compatibilitySection: some View {
        Section {
            Toggle("iTunes File Sharing", isOn: $options.forceFileSharing)
            Toggle("Files App Access", isOn: $options.forceDocumentBrowser)
            Toggle("Force Full Screen", isOn: $options.forceFullScreen)
            Toggle("Force ProMotion (120Hz)", isOn: $options.forceProMotion)
            Toggle("Force Game Mode", isOn: $options.forceGameMode)
            Toggle("Force Localized Display Name", isOn: $options.forceLocalizedDisplayName)
        } header: {
            Label("Compatibility", systemImage: "checkmark.seal.fill")
        } footer: {
            Text("Force Localized Display Name overrides the app name shown under every language the app supports, not just the default one.")
        }
    }

    private var removalSection: some View {
        Section {
            Toggle("Remove App Extensions", isOn: $options.removePlugins)
            Toggle("Remove Watch App", isOn: $options.removeWatchApp)
            Toggle("Remove Embedded Provisioning", isOn: $options.removeProvisioningProfile)
            Toggle("Remove Localizations Except English", isOn: $options.removeLocalizations)
            Toggle("Remove URL Schemes", isOn: $options.removeURLSchemes)
        } header: {
            Label("Removal", systemImage: "trash.fill")
        }
    }

    private var networkSection: some View {
        Section {
            Toggle("Allow Arbitrary Network Loads", isOn: $options.allowArbitraryLoads)
        } header: {
            Label("Network", systemImage: "network")
        }
    }

    private var tweaksSection: some View {
        Section {
            if dylibStore.dylibs.isEmpty {
                Text("No tweaks imported yet. Add .dylib or .deb files from Settings → Tweak Library.")
                    .font(SIFont.caption)
                    .foregroundStyle(SIColor.textSecondary)
            } else {
                ForEach(dylibStore.dylibs) { dylib in
                    Toggle(isOn: Binding(
                        get: { options.injectedDylibIDs.contains(dylib.id) },
                        set: { isOn in
                            if isOn {
                                options.injectedDylibIDs.append(dylib.id)
                            } else {
                                options.injectedDylibIDs.removeAll { $0 == dylib.id }
                            }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text(dylib.displayName)
                            Text(dylib.displaySize).font(SIFont.caption).foregroundStyle(SIColor.textSecondary)
                        }
                    }
                }
            }
            Toggle("Inject Weakly", isOn: $options.weakInjection)
            Toggle("Inject into Extensions", isOn: $options.injectIntoExtensions)
        } header: {
            Label("Tweaks", systemImage: "puzzlepiece.extension.fill")
        }
    }

    private var entitlementsSection: some View {
        Section {
            NavigationLink {
                EntitlementsEditorView(
                    text: Binding(
                        get: { options.entitlements ?? "" },
                        set: { options.entitlements = $0.isEmpty ? nil : $0 }
                    ),
                    certificateID: certificateID
                )
            } label: {
                HStack {
                    Text("Entitlements")
                    Spacer()
                    Text(options.entitlements == nil ? String(localized: "From Provisioning Profile") : String(localized: "Customized"))
                        .foregroundStyle(SIColor.textSecondary)
                }
            }
        } header: {
            Label("Entitlements", systemImage: "checkmark.shield.fill")
        } footer: {
            Text("Leave this untouched to sign with the entitlements baked into your provisioning profile.")
        }
    }

    private var advancedSection: some View {
        Section {
            Toggle("Use Instant-Resign Cache", isOn: $options.useCache)
            Toggle("Force Re-sign (skip zsign's own cache)", isOn: $options.stripExistingSignature)
            if showsInstallToggle {
                Toggle("Install After Signing", isOn: $options.installAfterSigning)
            }
        } header: {
            Label("Advanced", systemImage: "gearshape.2.fill")
        }
    }
}
