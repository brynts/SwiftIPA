import Foundation

enum SigningEngineError: LocalizedError {
    case certificateMissing
    case certificatePasswordMissing
    case noAppEntry

    var errorDescription: String? {
        switch self {
        case .certificateMissing:
            return String(localized: "No signing certificate is selected.")
        case .certificatePasswordMissing:
            return String(localized: "SwiftIPA doesn't have a saved password for this certificate. Re-add it from Certificates.")
        case .noAppEntry:
            return String(localized: "This app is no longer in your library.")
        }
    }
}

actor SigningEngine {
    static let shared = SigningEngine()

    private let cache = SigningCache.shared

    func run(jobs: [SigningJob]) async {
        let concurrency = max(1, min(ProcessInfo.processInfo.activeProcessorCount, jobs.count))
        await withTaskGroup(of: Void.self) { group in
            var iterator = jobs.makeIterator()
            var launched = 0

            func launchNext() {
                guard let job = iterator.next() else { return }
                launched += 1
                group.addTask { [weak self] in
                    await self?.execute(job)
                }
            }

            for _ in 0..<concurrency { launchNext() }
            while launched > 0 {
                await group.next()
                launched -= 1
                launchNext()
            }
        }
    }

    private func execute(_ job: SigningJob) async {
        do {
            let outputURL = try await sign(job: job)
            try AppLibraryStore.shared.markSigned(
                job.appEntryID,
                signedIPAURL: outputURL,
                options: job.options,
                certificateID: job.certificateID
            )
            try? FileManager.default.removeItem(at: outputURL)
        } catch {
            await MainActor.run { job.status = .failed(error.localizedDescription) }
        }
    }

    private func sign(job: SigningJob) async throws -> URL {
        guard let certificate = CertificateStore.shared.certificate(withID: job.certificateID) else {
            await MainActor.run { job.status = .failed(SigningEngineError.certificateMissing.localizedDescription) }
            throw SigningEngineError.certificateMissing
        }
        guard let password = CertificateStore.shared.password(for: certificate) else {
            await MainActor.run { job.status = .failed(SigningEngineError.certificatePasswordMissing.localizedDescription) }
            throw SigningEngineError.certificatePasswordMissing
        }

        await MainActor.run { job.status = .extracting }

        let p12URL = CertificateStore.shared.p12URL(for: certificate)
        let provisionURL = CertificateStore.shared.provisionURL(for: certificate)

        var cacheKey: String?
        if job.options.useCache,
           let sourceHash = FileHashing.sha256(of: job.sourceIPAURL),
           let optionsData = try? JSONEncoder().encode(job.options) {
            let optionsFingerprint = FileHashing.sha256(of: String(data: optionsData, encoding: .utf8) ?? "")
            let certFingerprint = (FileHashing.sha256(of: p12URL) ?? "") + (FileHashing.sha256(of: provisionURL) ?? "")
            let key = cache.key(sourceHash: sourceHash, optionsFingerprint: optionsFingerprint, certificateFingerprint: certFingerprint)
            cacheKey = key
            if let cached = cache.cachedIPA(for: key) {
                await MainActor.run { job.status = .cached }
                let tempCopy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).ipa")
                try FileManager.default.copyItem(at: cached, to: tempCopy)
                await MainActor.run { job.status = .done(0) }
                return tempCopy
            }
        }

        let started = Date()
        let extracted = try IPAService.extract(ipaURL: job.sourceIPAURL)
        defer { extracted.cleanUp() }

        await MainActor.run { job.status = .patching }
        try InfoPlistPatcher.apply(job.options, toPlistAt: extracted.infoPlistURL)
        if job.options.removeLocalizations {
            InfoPlistPatcher.removeLocalizations(inAppFolder: extracted.appFolder)
        }

        var entitlementsURL: URL?
        if let entitlementsText = job.options.entitlements, !entitlementsText.isEmpty {
            let tempEntitlements = extracted.extractionRoot.appendingPathComponent("entitlements.plist")
            try entitlementsText.write(to: tempEntitlements, atomically: true, encoding: .utf8)
            entitlementsURL = tempEntitlements
        }

        let dylibURLs = job.options.injectedDylibIDs.compactMap { dylibID -> URL? in
            guard let dylib = DylibLibraryStore.shared.dylibs.first(where: { $0.id == dylibID }) else { return nil }
            return DylibLibraryStore.shared.url(for: dylib)
        }

        var iconURL: URL?
        if let iconPath = job.options.customIconPath {
            iconURL = URL(fileURLWithPath: iconPath)
        }

        await MainActor.run { job.status = .signing }
        let originalBundleID = try IPAService.metadata(from: extracted).bundleIdentifier
        let resolvedBundleID = job.options.resolvedBundleIdentifier(original: originalBundleID)

        _ = try ZSignEngine.sign(
            extractionRoot: extracted.extractionRoot,
            p12URL: p12URL,
            p12Password: password,
            provisionURL: provisionURL,
            entitlementsURL: entitlementsURL,
            bundleIdentifier: resolvedBundleID,
            bundleName: job.options.displayName.isEmpty ? nil : job.options.displayName,
            bundleVersion: job.options.version.isEmpty ? nil : job.options.version,
            minimumOSVersion: job.options.minimumOSVersion.isEmpty ? nil : job.options.minimumOSVersion,
            iconURL: iconURL,
            dylibURLs: dylibURLs,
            removedDylibNames: [],
            removeExtensions: job.options.removePlugins,
            removeWatchApp: job.options.removeWatchApp,
            removeUISupportedDevices: job.options.removeDeviceRestrictions,
            removeProvisionAfterSigning: job.options.removeProvisioningProfile,
            weakInject: job.options.weakInjection,
            forceSign: job.options.stripExistingSignature
        )

        await MainActor.run { job.status = .packaging }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).ipa")
        try IPAService.repack(extracted: extracted, to: output)

        if let cacheKey {
            cache.store(key: cacheKey, ipaURL: output)
        }

        let elapsed = Date().timeIntervalSince(started)
        await MainActor.run { job.status = .done(elapsed) }
        return output
    }
}
