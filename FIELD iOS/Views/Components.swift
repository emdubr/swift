import SwiftUI

struct FieldHeader: View {
    var title: String
    var subtitle: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.subheadline.bold().monospaced())
                .tracking(0.65)
                .foregroundStyle(FieldTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer()
            if let subtitle { Text(subtitle.uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(FieldTheme.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.77) }
        }
    }
}

struct MetricTile: View {
    var label: String
    var value: String
    var detail: String? = nil
    var tone: Color = FieldTheme.accent
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.caption2.monospaced()).foregroundStyle(FieldTheme.dim)
            Text(value).font(.headline.monospaced()).foregroundStyle(tone)
                .lineLimit(1).minimumScaleFactor(0.75)
            if let detail { Text(detail).font(.caption2.monospaced()).foregroundStyle(FieldTheme.dim).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(FieldTheme.panelRaised.opacity(0.75))
        .overlay(Rectangle().stroke(FieldTheme.border.opacity(0.84), lineWidth: 1))
    }
}

struct ModuleRow: View {
    var title: String
    var symbol: String
    var subtitle: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 26).foregroundStyle(FieldTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct StatusPill: View {
    var text: String
    var tone: Color = FieldTheme.accent
    var body: some View {
        Text(text.uppercased()).font(.caption2.bold().monospaced())
            .foregroundStyle(tone)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(tone.opacity(0.12))
            .overlay(Rectangle().stroke(tone.opacity(0.55), lineWidth: 1))
    }
}

extension TimeInterval {
    var fieldDuration: String {
        guard isFinite && self >= 0 else { return "--" }
        let total = Int(self.rounded())
        let h = total / 3600, m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}


// Shared chrome for secondary workstations ONLY. The Home layout does not use
// these controls, so changes to Map / Route / Comms / Tools cannot shift Home.
struct SecondaryConsoleTitle: View {
    let title: String
    let status: String
    let symbol: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FieldTheme.accent)
            Text(title.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(FieldTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 3)
            Text(status.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(FieldTheme.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .frame(height: 43)
        .background(FieldTheme.panel)
        .overlay(alignment: .bottom) { FieldTheme.border.frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}

struct SecondaryConsolePanel<Content: View>: View {
    let title: String
    var detail: String = ""
    let content: Content

    init(title: String, detail: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .foregroundStyle(FieldTheme.text)
                Spacer(minLength: 4)
                if !detail.isEmpty {
                    Text(detail.uppercased())
                        .foregroundStyle(FieldTheme.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.35)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .overlay(alignment: .bottom) { FieldTheme.border.frame(height: 1) }

            content.padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldTheme.panel)
        .overlay(Rectangle().stroke(FieldTheme.border, lineWidth: 1))
    }
}

struct SecondaryConsoleButton: ButtonStyle {
    var emphasized: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(emphasized ? FieldTheme.background : FieldTheme.accent)
            .frame(maxWidth: .infinity, minHeight: 42)
            .padding(.horizontal, 7)
            .background(configuration.isPressed
                        ? FieldTheme.accent.opacity(0.70)
                        : (emphasized ? FieldTheme.accent : FieldTheme.panelRaised))
            .overlay(Rectangle().stroke(
                emphasized ? FieldTheme.accent : FieldTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
    }
}
