import SwiftUI

// The same restrained terminal palette as the browser console, with native
// touch targets and enough contrast for sunlight / smaller mobile displays.
struct FieldTheme {
    static let background = Color(red: 7.0 / 255, green: 16.0 / 255, blue: 9.0 / 255)
    static let panel = Color(red: 11.0 / 255, green: 21.0 / 255, blue: 13.0 / 255)
    static let panelRaised = Color(red: 13.0 / 255, green: 26.0 / 255, blue: 17.0 / 255)
    static let accent = Color(red: 114.0 / 255, green: 229.0 / 255, blue: 142.0 / 255)
    static let amber = Color(red: 1.0, green: 0.82, blue: 0.40)
    static let danger = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let text = Color(red: 186.0 / 255, green: 247.0 / 255, blue: 199.0 / 255)
    static let dim = Color(red: 106.0 / 255, green: 163.0 / 255, blue: 117.0 / 255)
    static let border = Color(red: 36.0 / 255, green: 85.0 / 255, blue: 55.0 / 255)
}

struct FieldPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [FieldTheme.panelRaised.opacity(0.58), FieldTheme.panel.opacity(0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
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
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                configuration.isPressed ? FieldTheme.panelRaised : FieldTheme.panel,
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(FieldTheme.border, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}
