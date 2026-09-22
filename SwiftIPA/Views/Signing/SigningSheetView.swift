import SwiftUI
import Combine

struct SigningSheetView: View {
    let entryID: UUID
    var onSignedSuccessfully: (() -> Void)?

    @ObservedObject private var library = AppLibraryStore.shared
    @ObservedObject private var certificateStore = CertificateStore.shared
    @ObservedObject private var dylibStore = DylibLibraryStore.shared
    @ObservedObject private var presetStore = PresetStore.shared

    @State private var options = SigningOptions()
    @State private var certificateID: UUID?
    @State private var isSigning = false
    @State private var jobStatus: SigningJobStatus = .queued
    @State private var errorMessage: String?
    @State private var showingSavePreset = false
    @State private var presetName = ""
    @State private var showingIconPicker = false

    @Environment(\.dismiss) private var dismiss

    private var entry: AppEntry? {
        library.apps.first { $0.id == entryID }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let entry {
                    presetSection
                    certificateSection
                    identitySection(entry: entry)
                    appearanceSection
                    modifiersSection
                    tweaksSection
                    entitlementsSection
                    advancedSection
                }
            }
            .siScreen()
            .navigationTitle("Sign")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isSigning)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        sign()
                    } label: {
                        if isSigning {
                            ProgressView()
                        } else {
                            Text("Sign")
                        }
                    }
                    .disabled(certificateID == nil || isSigning)
                }
            }
            .onAppear(perform: prepareDefaults)
            .alert("Signing Failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingSavePreset) {
                NameInputSheet(title: String(localized: "Save Preset"), placeholder: String(localized: "Preset name"), text: "", confirmTitle: String(localized: "Save")) { name in
                    presetStore.save(name: name, certificateID: certificateID, options: options)
                }
            }
        }
    }

    private var presetSection: some View {
        Section {
            if presetStore.presets.isEmpty {
                Text("No saved presets yet. Configure signing below, then save it as a preset.")
                    .font(SIFont.caption)
                    .foregroundStyle(SIColor.textSecondary)
            } else {
                Picker("Load Preset", selection: Binding<UUID?>(
                    get: { nil },
                    set: { id in
                        guard let id, let preset = presetStore.presets.first(where: { $0.id == id }) else { return }
                        options = preset.options
                        certificateID = preset.certificateID ?? certificateID
                        presetStore.markUsed(preset)
                    }
                )) {
                    Text("Choose a preset").tag(UUID?.none)
                    ForEach(presetStore.presets) { preset in
                        Text(preset.name).tag(UUID?.some(preset.id))
                    }
                }
            }
            Button {
                showingSavePreset = true
            } label: {
                Label("Save Current as Preset", systemImage: "square.and.arrow.down.on.square")
            }
        } header: {
            Text("Presets")
        }
    }

    private var certificateSection: some View {
        Section {
            if certificateStore.certificates.isEmpty {
                Text("Add a certificate in the Certificates tab first.")
                    .font(SIFont.caption)
                    .foregroundStyle(SIColor.danger)
            } else {
                Picker("Certificate", selection: $certificateID) {
                    ForEach(certificateStore.certificates) { certificate in
                        HStack {
                            Text(certificate.name)
                        }
                        .tag(UUID?.some(certificate.id))
                    }
                }
            }
        } header: {
            Text("Certificate")
        }
    }

    private func identitySection(entry: AppEntry) -> some View {
        Section {
            TextField("Display Name", text: $options.displayName)
                .autocorrectionDisabled()

            Picker("Bundle ID", selection: $options.bundleIdentifierRule) {
                ForEach(BundleIdentifierRule.allCases) { rule in
                    Text(rule.displayName).tag(rule)
                }
            }

            switch options.bundleIdentifierRule {
            case .appendSuffix:
                TextField("Suffix", text: $options.bundleIdentifierSuffix)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            case .custom:
                TextField("com.example.app", text: $options.bundleIdentifier)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            default:
                EmptyView()
            }

            HStack {
                TextField("Version", text: $options.version)
                Divider()
                TextField("Build", text: $options.build)
            }
            .keyboardType(.numbersAndPunctuation)

            TextField("Minimum iOS Version", text: $options.minimumOSVersion)
                .keyboardType(.numbersAndPunctuation)
        } header: {
            Text("Identity")
        } footer: {
            Text("Original bundle ID: \(entry.originalBundleIdentifier ?? entry.bundleIdentifier)")
        }
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
            Text("Appearance")
        } footer: {
            Text("Design forces an app to use, or not use, iOS 26's Liquid Glass redesign. Not every app supports being switched either way.")
        }
    }

    private var modifiersSection: some View {
        Section {
            Toggle("Remove App Extensions", isOn: $options.removePlugins)
            Toggle("Remove Watch App", isOn: $options.removeWatchApp)
            Toggle("Remove Embedded Provisioning", isOn: $options.removeProvisioningProfile)
            Toggle("Remove Localizations Except English", isOn: $options.removeLocalizations)
            Toggle("Remove URL Schemes", isOn: $options.removeURLSchemes)
            Toggle("iTunes File Sharing", isOn: $options.forceFileSharing)
            Toggle("Files App Access", isOn: $options.forceDocumentBrowser)
            Toggle("Force Full Screen", isOn: $options.forceFullScreen)
            Toggle("Force ProMotion (120Hz)", isOn: $options.forceProMotion)
            Toggle("Force Game Mode", isOn: $options.forceGameMode)
            Toggle("Allow Arbitrary Network Loads", isOn: $options.allowArbitraryLoads)
            Toggle("Force Localized Display Name", isOn: $options.forceLocalizedDisplayName)
        } header: {
            Text("Modifiers")
        } footer: {
            Text("Force Localized Display Name overrides the app name shown under every language the app supports, not just the default one.")
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
            Text("Tweaks")
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
            Text("Entitlements")
        } footer: {
            Text("Leave this untouched to sign with the entitlements baked into your provisioning profile.")
        }
    }

    private var advancedSection: some View {
        Section {
            Toggle("Use Instant-Resign Cache", isOn: $options.useCache)
            Toggle("Force Re-sign (skip zsign's own cache)", isOn: $options.stripExistingSignature)
            Toggle("Install After Signing", isOn: $options.installAfterSigning)
        } header: {
            Text("Advanced")
        } footer: {
            if isSigning {
                signingProgressFooter
            }
        }
    }

    @ViewBuilder
    private var signingProgressFooter: some View {
        switch jobStatus {
        case .queued: Text("Queued…")
        case .extracting: Text("Unpacking IPA…")
        case .patching: Text("Applying modifiers…")
        case .signing: Text("Signing with zsign…")
        case .packaging: Text("Repacking IPA…")
        case .cached: Text("Found an identical signed build in cache — skipping re-sign…")
        case .done(let seconds):
            if seconds < 0.05 {
                Text("Done instantly from cache.")
            } else {
                Text(String(format: String(localized: "Done in %.1fs."), seconds))
            }
        case .failed(let message): Text(message).foregroundStyle(SIColor.danger)
        }
    }

    private func prepareDefaults() {
        guard let entry else { return }
        certificateID = certificateStore.defaultCertificateID ?? certificateStore.certificates.first?.id
        if options.displayName.isEmpty { options.displayName = entry.name }
        if options.version.isEmpty { options.version = entry.version }
        if options.build.isEmpty { options.build = entry.build }
        if options.minimumOSVersion.isEmpty { options.minimumOSVersion = entry.minimumOSVersion }
    }

    private func sign() {
        guard let entry, let certificateID else { return }
        isSigning = true

        let job = SigningJob(
            appEntryID: entry.id,
            sourceIPAURL: library.ipaURL(for: entry),
            displayName: entry.name,
            options: options,
            certificateID: certificateID
        )

        Task {
            let cancellable = job.$status.sink { status in
                Task { @MainActor in jobStatus = status }
            }
            await SigningEngine.shared.run(jobs: [job])
            cancellable.cancel()

            await MainActor.run {
                isSigning = false
                if case .failed(let message) = job.status {
                    errorMessage = message
                } else {
                    let shouldInstall = options.installAfterSigning
                    dismiss()
                    if shouldInstall {
                        onSignedSuccessfully?()
                    }
                }
            }
        }
    }
}
