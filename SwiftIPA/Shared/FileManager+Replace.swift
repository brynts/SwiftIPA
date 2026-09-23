import Foundation

extension FileManager {
    func replaceItem(at destination: URL, withItemAt source: URL) throws {
        if fileExists(atPath: destination.path) {
            try removeItem(at: destination)
        }
        do {
            try linkItem(at: source, to: destination)
        } catch {
            try copyItem(at: source, to: destination)
        }
    }
}
