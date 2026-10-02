import SwiftUI

struct ReadinessView: View {
    @EnvironmentObject private var state: AppState
    var embedded: Bool = false

    var body: some View {
        Group {
            if embedded {
                checklist
            } else {
                checklist.fieldPanel()
            }
        }
        .onChange(of: state.readiness) { _, _ in state.persist() }
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldHeader(title: "Readiness", subtitle: "\(state.readiness.completedCount)/\(state.readiness.totalCount) // \(state.readiness.score)%")
            readinessRow("Navigation", "GPS and route confirmed", isOn: $state.readiness.navigationChecked)
            readinessRow("Weather", "Forecast / hazards reviewed", isOn: $state.readiness.weatherChecked)
            readinessRow("Battery", "Phone + field device power", isOn: $state.readiness.batteryChecked)
            readinessRow("Water", "Water carried / source plan", isOn: $state.readiness.waterChecked)
            readinessRow("Emergency", "Contact + bailout plan", isOn: $state.readiness.emergencyPlanChecked)
            readinessRow("Offline map", "Verify this imported offline basemap renders and covers your full route before departure", isOn: $state.readiness.offlineMapChecked)
            readinessRow("Route", "Route reviewed and saved", isOn: $state.readiness.routeChecked)
            readinessRow("Comms", "Primary/backup comms checked", isOn: $state.readiness.commsChecked)
        }
    }

    private func readinessRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn.wrappedValue ? FieldTheme.accent : FieldTheme.dim)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).foregroundStyle(FieldTheme.text)
                    Text(subtitle).font(.caption2).foregroundStyle(FieldTheme.dim)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
