import Foundation

enum CertificateHealth: String, Codable {
    case unknown
    case valid
    case expiringSoon
    case expired
    case revoked

    var isUsable: Bool {
        self == .valid || self == .expiringSoon || self == .unknown
    }
}

struct SigningCertificate: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var teamName: String?
    var teamIdentifier: String?
    var issuedAt: Date?
    var expiresAt: Date?
    var addedAt: Date
    var p12FileName: String
    var provisionFileName: String
    var provisionedDeviceCount: Int?
    var supportsUnrestrictedEntitlements: Bool
    var lastRevocationCheck: Date?
    var knownRevoked: Bool

    init(
        id: UUID = UUID(),
        name: String,
        teamName: String? = nil,
        teamIdentifier: String? = nil,
        issuedAt: Date? = nil,
        expiresAt: Date? = nil,
        addedAt: Date = Date(),
        p12FileName: String,
        provisionFileName: String,
        provisionedDeviceCount: Int? = nil,
        supportsUnrestrictedEntitlements: Bool = false,
        lastRevocationCheck: Date? = nil,
        knownRevoked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.teamName = teamName
        self.teamIdentifier = teamIdentifier
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.addedAt = addedAt
        self.p12FileName = p12FileName
        self.provisionFileName = provisionFileName
        self.provisionedDeviceCount = provisionedDeviceCount
        self.supportsUnrestrictedEntitlements = supportsUnrestrictedEntitlements
        self.lastRevocationCheck = lastRevocationCheck
        self.knownRevoked = knownRevoked
    }

    var daysRemaining: Int? {
        guard let expiresAt else { return nil }
        let seconds = expiresAt.timeIntervalSinceNow
        return Int((seconds / 86400).rounded(.down))
    }

    var health: CertificateHealth {
        if knownRevoked { return .revoked }
        guard let days = daysRemaining else { return .unknown }
        if days < 0 { return .expired }
        if days <= 7 { return .expiringSoon }
        return .valid
    }

    var displayExpiry: String {
        guard let expiresAt else { return String(localized: "Unknown expiry") }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: expiresAt)
    }
}
