import SwiftUI

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct CertificateHealthBadge: View {
    let health: CertificateHealth

    var body: some View {
        switch health {
        case .valid:
            StatusBadge(text: String(localized: "Valid"), color: SIColor.success)
        case .expiringSoon:
            StatusBadge(text: String(localized: "Expiring soon"), color: SIColor.warning)
        case .expired:
            StatusBadge(text: String(localized: "Expired"), color: SIColor.danger)
        case .revoked:
            StatusBadge(text: String(localized: "Revoked"), color: SIColor.danger)
        case .unknown:
            StatusBadge(text: String(localized: "Unknown"), color: SIColor.textSecondary)
        }
    }
}
