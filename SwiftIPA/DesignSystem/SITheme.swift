import SwiftUI

enum SIThemeID: String, CaseIterable, Codable, Identifiable {
    case orangeDark
    case lightBlueDark
    case redDark
    case orangeLight
    case lightBlueLight
    case redLight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .orangeDark: return String(localized: "Orange & Black")
        case .lightBlueDark: return String(localized: "Light Blue & Black")
        case .redDark: return String(localized: "Red & Black")
        case .orangeLight: return String(localized: "Orange & White")
        case .lightBlueLight: return String(localized: "Light Blue & White")
        case .redLight: return String(localized: "Red & White")
        }
    }
}

struct SITheme {
    let id: SIThemeID
    let background: Color
    let surface: Color
    let surfaceElevated: Color
    let border: Color
    let accent: Color
    let accentMuted: Color
    let textPrimary: Color
    let textSecondary: Color
    let danger: Color
    let warning: Color
    let success: Color
    let colorScheme: ColorScheme

    static let orangeDark = SITheme(
        id: .orangeDark,
        background: Color(hex: 0x000000),
        surface: Color(hex: 0x121212),
        surfaceElevated: Color(hex: 0x1C1C1E),
        border: Color(hex: 0x2C2C2E),
        accent: Color(hex: 0xFF9F0A),
        accentMuted: Color(hex: 0xFF9F0A, alpha: 0.16),
        textPrimary: .white,
        textSecondary: Color(hex: 0x9A9A9E),
        danger: Color(hex: 0xFF453A),
        warning: Color(hex: 0xFFD60A),
        success: Color(hex: 0x30D158),
        colorScheme: .dark
    )

    static let lightBlueDark = SITheme(
        id: .lightBlueDark,
        background: Color(hex: 0x000000),
        surface: Color(hex: 0x121212),
        surfaceElevated: Color(hex: 0x1C1C1E),
        border: Color(hex: 0x2C2C2E),
        accent: Color(hex: 0x4CC2FF),
        accentMuted: Color(hex: 0x4CC2FF, alpha: 0.16),
        textPrimary: .white,
        textSecondary: Color(hex: 0x9A9A9E),
        danger: Color(hex: 0xFF453A),
        warning: Color(hex: 0xFFD60A),
        success: Color(hex: 0x30D158),
        colorScheme: .dark
    )

    static let redDark = SITheme(
        id: .redDark,
        background: Color(hex: 0x000000),
        surface: Color(hex: 0x121212),
        surfaceElevated: Color(hex: 0x1C1C1E),
        border: Color(hex: 0x2C2C2E),
        accent: Color(hex: 0xFF3B30),
        accentMuted: Color(hex: 0xFF3B30, alpha: 0.16),
        textPrimary: .white,
        textSecondary: Color(hex: 0x9A9A9E),
        danger: Color(hex: 0xFF453A),
        warning: Color(hex: 0xFFD60A),
        success: Color(hex: 0x30D158),
        colorScheme: .dark
    )

    static let orangeLight = SITheme(
        id: .orangeLight,
        background: Color(hex: 0xFFFFFF),
        surface: Color(hex: 0xF2F2F7),
        surfaceElevated: Color(hex: 0xE5E5EA),
        border: Color(hex: 0xD1D1D6),
        accent: Color(hex: 0xFF9F0A),
        accentMuted: Color(hex: 0xFF9F0A, alpha: 0.16),
        textPrimary: .black,
        textSecondary: Color(hex: 0x6E6E73),
        danger: Color(hex: 0xD70015),
        warning: Color(hex: 0xB25000),
        success: Color(hex: 0x248A3D),
        colorScheme: .light
    )

    static let lightBlueLight = SITheme(
        id: .lightBlueLight,
        background: Color(hex: 0xFFFFFF),
        surface: Color(hex: 0xF2F2F7),
        surfaceElevated: Color(hex: 0xE5E5EA),
        border: Color(hex: 0xD1D1D6),
        accent: Color(hex: 0x4CC2FF),
        accentMuted: Color(hex: 0x4CC2FF, alpha: 0.16),
        textPrimary: .black,
        textSecondary: Color(hex: 0x6E6E73),
        danger: Color(hex: 0xD70015),
        warning: Color(hex: 0xB25000),
        success: Color(hex: 0x248A3D),
        colorScheme: .light
    )

    static let redLight = SITheme(
        id: .redLight,
        background: Color(hex: 0xFFFFFF),
        surface: Color(hex: 0xF2F2F7),
        surfaceElevated: Color(hex: 0xE5E5EA),
        border: Color(hex: 0xD1D1D6),
        accent: Color(hex: 0xFF3B30),
        accentMuted: Color(hex: 0xFF3B30, alpha: 0.16),
        textPrimary: .black,
        textSecondary: Color(hex: 0x6E6E73),
        danger: Color(hex: 0xD70015),
        warning: Color(hex: 0xB25000),
        success: Color(hex: 0x248A3D),
        colorScheme: .light
    )

    static func theme(for id: SIThemeID) -> SITheme {
        switch id {
        case .orangeDark: return .orangeDark
        case .lightBlueDark: return .lightBlueDark
        case .redDark: return .redDark
        case .orangeLight: return .orangeLight
        case .lightBlueLight: return .lightBlueLight
        case .redLight: return .redLight
        }
    }
}
