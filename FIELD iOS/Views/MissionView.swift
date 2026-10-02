import SwiftUI

struct MissionView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        Form {
            Section("Mission") {
                TextField("Name", text: $state.mission.name)
                TextField("Objective", text: $state.mission.objective, axis: .vertical)
                Toggle("Mission active", isOn: $state.mission.active)
                Toggle("Group expedition tracking", isOn: $state.mission.groupTrackingEnabled)
                Stepper("Separation warning: \(state.mission.separationLimitMiles, specifier: "%.2f") mi", value: $state.mission.separationLimitMiles, in: 0.05...10, step: 0.05)
            }
            Section {
                Button(state.mission.active ? "Update Mission" : "Save Mission") {
                    if state.mission.active && state.mission.startedAt == nil { state.mission.startedAt = .now }
                    state.persist(); state.log("MISSION", "Mission configuration updated")
                }
            }
        }.navigationTitle("Mission Mode")
    }
}
