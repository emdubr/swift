import SwiftUI

struct FieldHeader: View {
    var title: String
    var subtitle: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased()).font(.headline.monospaced()).foregroundStyle(FieldTheme.text)
            Spacer()
            if let subtitle { Text(subtitle.uppercased()).font(.caption2.monospaced()).foregroundStyle(FieldTheme.dim) }
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
        .background(FieldTheme.panelRaised.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
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
            .background(tone.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(tone.opacity(0.55)))
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
