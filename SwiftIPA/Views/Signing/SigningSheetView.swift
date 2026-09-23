import SwiftUI
import Combine

struct SigningSheetView: View {
    let entryID: UUID
    var onSignedSuccessfully: (() -> Void)?

    @ObservedObject private var library = AppLibraryStore.shared
    @ObservedObject private var certificateStore = CertificateStore.shared
    @ObservedObject private var presetStore = PresetStore.shared
    @ObservedObject private var defaultsStore = DefaultSigningOptionsStore.shared

    @State private var options = SigningOptions()
    @State private var certificateID: UUID?
    @State private var isSigning = false
    @State private var jobStatus: SigningJobStatus = .queued
    @State private var errorMessage: String?
    @State private var showingSavePreset = false
    @State private var presetName = ""
    @State private var showingIconPicker = false
    @State private var hasSeededDefaults = false

    @Environment(\.dismiss) private var dismiss

    private var entry: AppEntry? {
        library.apps.first { $0.id == entryID }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let entry {
                    if isSigning {
                        progressSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    presetSection
                    certificateSection
                    identitySection(entry: entry)
                    SigningOptionsEditor(options: $options, certificateID: certificateID)
                }
            }
            .animation(.easeOut(duration: 0.25), value: isSigning)
            .siScreen()
            .presentationDragIndicator(.visible)
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
            Label("Presets", systemImage: "slider.horizontal.3")
        }
    }

    private var certificateSection: some View {
        Section {
            if certificateStore.certificates.isEmpty {
                Text("Add a certificate in Settings first.")
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
            Label("Certificate", systemImage: "checkmark.seal.fill")
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
            Label("Identity", systemImage: "person.text.rectangle.fill")
        } footer: {
            Text("Original bundle ID: \(entry.originalBundleIdentifier ?? entry.bundleIdentifier)")
        }
    }

    private var progressSection: some View {
        Section {
            HStack(spacing: SISpacing.sm) {
                if jobStatus.isInProgress {
                    ProgressView()
                }
                signingProgressFooter
                    .transition(.opacity)
            }
            .animation(.easeOut(duration: 0.2), value: jobStatus)
        } header: {
            Label("Progress", systemImage: "bolt.fill")
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
        guard !hasSeededDefaults else { return }
        hasSeededDefaults = true
        options = defaultsStore.makeOptions(seededWith: entry)
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
