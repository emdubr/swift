import SwiftUI

struct WaypointsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @State private var name = ""
    @State private var kind: WaypointKind = .note

    var body: some View {
        List {
            Section("Add at current position") {
                TextField("Waypoint name", text: $name)
                Picker("Type", selection: $kind) { ForEach(WaypointKind.allCases) { Text($0.rawValue).tag($0) } }
                Button("Add Waypoint") { add() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || location.location == nil)
            }
            Section("Saved") {
                if state.waypoints.isEmpty { Text("No saved waypoints.").foregroundStyle(.secondary) }
                ForEach(state.waypoints) { w in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack { Text(w.name).font(.headline); Spacer(); StatusPill(text: w.kind.rawValue) }
                        Text(String(format: "%.5f, %.5f", w.point.latitude, w.point.longitude)).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }.onDelete { offsets in state.waypoints.remove(atOffsets: offsets); state.persist() }
            }
        }.navigationTitle("Waypoints")
    }

    private func add() {
        guard let loc = location.location else { return }
        state.addWaypoint(Waypoint(name: name, kind: kind, point: RoutePoint(location: loc)))
        name = ""
    }
}
