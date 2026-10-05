import SwiftUI

// Compact mission console; saved values and activation behavior are unchanged.
struct MissionView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        VStack(spacing: 0) {
            SecondaryConsoleTitle(title: "MISSION CONTROL",
                                  status: state.mission.active ? "MISSION ACTIVE" : "STANDBY",
                                  symbol: "scope")
            ScrollView {
                VStack(spacing: 10) {
                    SecondaryConsolePanel(title: "Expedition", detail: "ON DEVICE") {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("MISSION NAME")
                                    .font(.caption2.bold().monospaced()).foregroundStyle(FieldTheme.dim)
                                TextField("Name", text: $state.mission.name)
                                    .textInputAutocapitalization(.words)
                                    .padding(10).background(FieldTheme.panelRaised)
                                    .overlay(Rectangle().stroke(FieldTheme.border))
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text("OBJECTIVE")
                                    .font(.caption2.bold().monospaced()).foregroundStyle(FieldTheme.dim)
                                TextField("Objective", text: $state.mission.objective, axis: .vertical)
                                    .lineLimit(2...4)
                                    .padding(10).background(FieldTheme.panelRaised)
                                    .overlay(Rectangle().stroke(FieldTheme.border))
                            }
                        }
                    }
                    SecondaryConsolePanel(title: "Group & safety", detail: "CONFIGURATION") {
                        VStack(alignment: .leading, spacing: 13) {
                            Toggle("MISSION ACTIVE", isOn: $state.mission.active)
                            Divider().overlay(FieldTheme.border)
                            Toggle("GROUP TRACKING", isOn: $state.mission.groupTrackingEnabled)
                            Divider().overlay(FieldTheme.border)
                            Stepper(value: $state.mission.separationLimitMiles,
                                    in: 0.05...10, step: 0.05) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("SEPARATION WARNING").font(.caption2.bold().monospaced())
                                    Text(String(format: "%.2f MI", state.mission.separationLimitMiles))
                                        .font(.headline.bold().monospaced())
                                        .foregroundStyle(FieldTheme.accent)
                                }
                            }
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .tint(FieldTheme.accent)
                        .foregroundStyle(FieldTheme.text)
                    }
                    Button(state.mission.active ? "UPDATE MISSION" : "SAVE MISSION") {
                        if state.mission.active && state.mission.startedAt == nil {
                            state.mission.startedAt = .now
                        }
                        state.persist()
                        state.log("MISSION", "Mission configuration updated")
                    }
                    .buttonStyle(SecondaryConsoleButton(emphasized: true))
                    Text("Changes remain local to FIELD / OS on this device.")
                        .font(.caption2.monospaced()).foregroundStyle(FieldTheme.dim)
                }
                .padding(10)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(FieldTheme.background.ignoresSafeArea())
        // Keep the compact iOS back affordance when opened from Tools.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
