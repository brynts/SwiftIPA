import Foundation

struct InspectionReport: Identifiable, Hashable {
    let id = UUID()
    var appName: String
    var bundleIdentifier: String
    var version: String
    var build: String
    var minimumOSVersion: String
    var supportedDevices: [String]
    var uncompressedSize: Int64
    var executables: [MachOSummary]
    var frameworks: [String]
    var plugins: [String]
    var hasWatchApp: Bool
    var entitlements: String?
    var urlSchemes: [String]
    var localizations: [String]
    var findings: [InspectionFinding]

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: uncompressedSize, countStyle: .file)
    }
}

struct MachOSummary: Identifiable, Hashable {
    let id = UUID()
    var path: String
    var architectures: [String]
    var isEncrypted: Bool
    var isSigned: Bool
    var linkedDylibs: [String]
    var rpaths: [String]
    var byteSize: Int64

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
    }
}

enum FindingSeverity: Int, Comparable {
    case info
    case warning
    case blocker

    static func < (lhs: FindingSeverity, rhs: FindingSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var symbolName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .blocker: return "xmark.octagon.fill"
        }
    }
}

struct InspectionFinding: Identifiable, Hashable {
    let id = UUID()
    var severity: FindingSeverity
    var title: String
    var detail: String
}
