import Foundation
import UIKit

enum InboxStore {
    struct Item {
        let suggestedName: String
        let data: Data
    }

    private static let itemType = "com.xsxs18.swiftipa.inbox-item"

    static func queue(_ items: [Item]) {
        UIPasteboard.general.items = items.compactMap { item in
            guard let nameData = item.suggestedName.data(using: .utf8), nameData.count <= UInt32.max else { return nil }
            var payload = encodedUInt32(UInt32(nameData.count))
            payload.append(nameData)
            payload.append(item.data)
            return [itemType: payload]
        }
    }

    static func takePending() -> [Item] {
        var remaining: [[String: Any]] = []
        var results: [Item] = []
        for entry in UIPasteboard.general.items {
            if let payload = entry[itemType] as? Data, let item = decode(payload) {
                results.append(item)
            } else {
                remaining.append(entry)
            }
        }
        if !results.isEmpty {
            UIPasteboard.general.items = remaining
        }
        return results
    }

    private static func encodedUInt32(_ value: UInt32) -> Data {
        Data([
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ])
    }

    private static func decodeUInt32(_ data: Data) -> UInt32 {
        data.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private static func decode(_ payload: Data) -> Item? {
        guard payload.count >= 4 else { return nil }
        var cursor = payload.startIndex
        let nameLength = Int(decodeUInt32(payload[cursor..<(cursor + 4)]))
        cursor += 4
        guard cursor + nameLength <= payload.endIndex else { return nil }
        guard let name = String(data: payload[cursor..<(cursor + nameLength)], encoding: .utf8) else { return nil }
        cursor += nameLength
        let fileData = payload[cursor...]
        return Item(suggestedName: name, data: Data(fileData))
    }
}
