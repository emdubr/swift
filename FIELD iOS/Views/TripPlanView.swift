import SwiftUI

struct TripPlanView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        Form {
            Section("Plan") {
                TextField("Trip name", text: $state.tripPlan.name)
                DatePicker("Start", selection: $state.tripPlan.startDate)
                Stepper("Planned duration: \(state.tripPlan.plannedDurationHours, specifier: "%.1f") h", value: $state.tripPlan.plannedDurationHours, in: 0.5...72, step: 0.5)
                Stepper("Check-in every \(state.tripPlan.checkInIntervalMinutes) min", value: $state.tripPlan.checkInIntervalMinutes, in: 15...720, step: 15)
                DatePicker("Turnaround", selection: $state.tripPlan.turnaroundTime)
            }
            Section("Emergency") {
                TextField("Emergency contact / note", text: $state.tripPlan.emergencyContact)
                TextField("Trip notes", text: $state.tripPlan.notes, axis: .vertical)
            }
            Section { Button("Save Trip Plan") { state.persist(); state.log("TRIP", "Updated trip plan \(state.tripPlan.name)") } }
        }.navigationTitle("Trip Plan")
    }
}
