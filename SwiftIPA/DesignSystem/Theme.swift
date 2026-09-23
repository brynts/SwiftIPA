import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum SIColor {
    static var background: Color { ThemeManager.shared.current.background }
    static var surface: Color { ThemeManager.shared.current.surface }
    static var surfaceElevated: Color { ThemeManager.shared.current.surfaceElevated }
    static var border: Color { ThemeManager.shared.current.border }
    static var accent: Color { ThemeManager.shared.current.accent }
    static var accentMuted: Color { ThemeManager.shared.current.accentMuted }
    static var textPrimary: Color { ThemeManager.shared.current.textPrimary }
    static var textSecondary: Color { ThemeManager.shared.current.textSecondary }
    static var danger: Color { ThemeManager.shared.current.danger }
    static var warning: Color { ThemeManager.shared.current.warning }
    static var success: Color { ThemeManager.shared.current.success }
}

enum SISpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum SIRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
}

enum SIFont {
    static let title = Font.system(.title2, design: .rounded).weight(.bold)
    static let headline = Font.system(.headline, design: .rounded)
    static let body = Font.system(.body, design: .default)
    static let mono = Font.system(.footnote, design: .monospaced)
    static let caption = Font.system(.caption, design: .default)
}

struct SIPrimaryButtonStyle: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SIFont.headline)
            .foregroundStyle(Color.black)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, SISpacing.sm + 2)
            .padding(.horizontal, SISpacing.md)
            .background(SIColor.accent.opacity(configuration.isPressed ? 0.7 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: SIRadius.sm, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SISecondaryButtonStyle: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SIFont.headline)
            .foregroundStyle(SIColor.accent)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, SISpacing.sm + 2)
            .padding(.horizontal, SISpacing.md)
            .background(SIColor.accentMuted.opacity(configuration.isPressed ? 0.5 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: SIRadius.sm, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SIIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(SIColor.accent)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SIPressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SICardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(SIColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: SIRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SIRadius.md, style: .continuous)
                    .stroke(SIColor.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 2)
    }
}

struct SIScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(SIColor.background.ignoresSafeArea())
    }
}

extension View {
    func siCard() -> some View {
        modifier(SICardBackground())
    }

    func siScreen() -> some View {
        modifier(SIScreenBackground())
    }
}

extension ButtonStyle where Self == SIPrimaryButtonStyle {
    static var siPrimary: SIPrimaryButtonStyle { SIPrimaryButtonStyle() }
    static var siPrimaryWide: SIPrimaryButtonStyle { SIPrimaryButtonStyle(fullWidth: true) }
}

extension ButtonStyle where Self == SISecondaryButtonStyle {
    static var siSecondary: SISecondaryButtonStyle { SISecondaryButtonStyle() }
    static var siSecondaryWide: SISecondaryButtonStyle { SISecondaryButtonStyle(fullWidth: true) }
}

extension ButtonStyle where Self == SIIconButtonStyle {
    static var siIcon: SIIconButtonStyle { SIIconButtonStyle() }
}

extension ButtonStyle where Self == SIPressableCardStyle {
    static var siPressableCard: SIPressableCardStyle { SIPressableCardStyle() }
}
