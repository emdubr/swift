import SwiftUI

struct FieldTheme {
    static let background = Color(red: 0.025, green: 0.055, blue: 0.038)
    static let panel = Color(red: 0.045, green: 0.095, blue: 0.065)
    static let panelRaised = Color(red: 0.060, green: 0.125, blue: 0.082)
    static let accent = Color(red: 0.45, green: 0.96, blue: 0.48)
    static let amber = Color(red: 1.0, green: 0.73, blue: 0.24)
    static let danger = Color(red: 1.0, green: 0.30, blue: 0.26)
    static let text = Color(red: 0.80, green: 0.98, blue: 0.82)
    static let dim = Color(red: 0.48, green: 0.66, blue: 0.50)
    static let border = Color(red: 0.19, green: 0.48, blue: 0.24)
}

struct FieldPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(FieldTheme.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FieldTheme.border.opacity(0.75), lineWidth: 1)
            }
    }
}

extension View {
    func fieldPanel() -> some View { modifier(FieldPanelModifier()) }
}

struct TerminalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold).monospaced())
            .foregroundStyle(FieldTheme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? FieldTheme.panelRaised : FieldTheme.panel)
            .overlay {
                RoundedRectangle(cornerRadius: 10).stroke(FieldTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
