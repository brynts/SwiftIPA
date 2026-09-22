import UIKit
import SwiftUI

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        presentStatus()
        extractAttachments { [weak self] items in
            DispatchQueue.main.async {
                self?.finish(with: items)
            }
        }
    }

    private func presentStatus() {
        let hosting = UIHostingController(rootView: ShareStatusView())
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }

    private func finish(with items: [InboxStore.Item]) {
        guard !items.isEmpty else {
            let error = NSError(domain: "com.xsxs18.SwiftIPA.ShareExtension", code: -1)
            extensionContext?.cancelRequest(withError: error)
            return
        }
        InboxStore.queue(items)
        guard let url = URL(string: "swiftipa://import") else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }
        extensionContext?.open(url) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func extractAttachments(completion: @escaping ([InboxStore.Item]) -> Void) {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion([])
            return
        }
        let providers = extensionItems.compactMap { $0.attachments }.flatMap { $0 }
        guard !providers.isEmpty else {
            completion([])
            return
        }

        let resultsLock = NSLock()
        var results: [InboxStore.Item] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            loadFile(from: provider) { item in
                if let item {
                    resultsLock.lock()
                    results.append(item)
                    resultsLock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(results)
        }
    }

    private func loadFile(from provider: NSItemProvider, completion: @escaping (InboxStore.Item?) -> Void) {
        let identifiers = provider.registeredTypeIdentifiers
        guard !identifiers.isEmpty else {
            completion(nil)
            return
        }
        tryLoad(from: provider, identifiers: identifiers, index: 0, completion: completion)
    }

    private func tryLoad(from provider: NSItemProvider, identifiers: [String], index: Int, completion: @escaping (InboxStore.Item?) -> Void) {
        guard index < identifiers.count else {
            completion(nil)
            return
        }
        provider.loadFileRepresentation(forTypeIdentifier: identifiers[index]) { [weak self] url, error in
            guard let self else { return }
            guard let url, error == nil, url.pathExtension.lowercased() == "ipa" else {
                self.tryLoad(from: provider, identifiers: identifiers, index: index + 1, completion: completion)
                return
            }
            guard let data = try? Data(contentsOf: url) else {
                self.tryLoad(from: provider, identifiers: identifiers, index: index + 1, completion: completion)
                return
            }
            completion(InboxStore.Item(suggestedName: url.lastPathComponent, data: data))
        }
    }
}

private struct ShareStatusView: View {
    var body: some View {
        VStack(spacing: SISpacing.md) {
            ProgressView()
                .tint(SIColor.accent)
            Text("Sending to SwiftIPA…")
                .foregroundStyle(SIColor.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SIColor.background)
    }
}
