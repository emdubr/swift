import SwiftUI

struct FieldLogView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @State private var note = ""

    var body: some View {
        List {
            Section("Scratchpad") {
                TextEditor(text: $state.scratchpad).frame(minHeight: 100)
                Button("Save Scratchpad") { state.persist() }
            }
            Section("New event") {
                TextField("Note", text: $note, axis: .vertical)
                Button("Log Note") { add(markPosition: false) }.disabled(note.isEmpty)
                Button("Mark Current Position") { add(markPosition: true) }.disabled(location.location == nil)
            }
            Section("Timeline") {
                ForEach(state.fieldLog.sorted(by: { $0.createdAt > $1.createdAt })) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack { Text(entry.category).font(.caption.bold()); Spacer(); Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2) }
                        Text(entry.text)
                        if let p = entry.point { Text(String(format: "%.5f, %.5f", p.latitude, p.longitude)).font(.caption2.monospaced()).foregroundStyle(.secondary) }
                    }
                }
            }
        }.navigationTitle("Field Log")
    }

    private func add(markPosition: Bool) {
        let point = markPosition ? location.location.map(RoutePoint.init(location:)) : nil
        state.log(markPosition ? "MARK" : "NOTE", note.isEmpty ? "Position mark" : note, point: point)
        note = ""
    }
}
