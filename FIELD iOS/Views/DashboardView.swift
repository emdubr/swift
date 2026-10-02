import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var sensor: SensorService
    @EnvironmentObject private var mesh: MeshService
    @EnvironmentObject private var track: TrackRecorder
    @EnvironmentObject private var checkIn: CheckInService

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    fieldStatus
                    priorityPanel
                    quickActions
                    routePanel
                    ReadinessView()
                    devicePanel
                }.padding(.horizontal, 12).padding(.bottom, 18)
            }
            .background(FieldTheme.background)
            .navigationTitle("FIELD / OS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { StatusPill(text: state.settings.offlineMode ? "OFFLINE" : "FIELD") }
                ToolbarItem(placement: .topBarTrailing) { Button { state.settings.offlineMode.toggle(); state.persist() } label: { Image(systemName: state.settings.offlineMode ? "wifi.slash" : "wifi") } }
            }
            .navigationDestination(for: AppModule.self) { ModuleDestination(module: $0) }
        }
    }

    private var fieldStatus: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                CompactStatus(label: "GNSS", value: location.location == nil ? "SEARCH" : "3D FIX", good: location.location != nil)
                CompactStatus(label: "MESH", value: mesh.linkState == .connected ? "LINK" : mesh.linkState.rawValue, good: mesh.linkState == .connected)
                CompactStatus(label: "TRACK", value: track.state.rawValue.uppercased(), good: track.state == .recording)
            }
            HStack(spacing: 8) {
                MetricTile(label: "ALT", value: altitudeText, detail: accuracyText)
                MetricTile(label: "BAT", value: sensor.snapshot.batteryPercent.map { "\($0)%" } ?? "--", detail: sensor.snapshot.lowPowerMode ? "LOW POWER" : "LOCAL")
                MetricTile(label: "READY", value: "\(state.readiness.score)%", detail: "\(state.readiness.completedCount)/\(state.readiness.totalCount)")
            }
        }
    }

    private var priorityPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            FieldHeader(title: "What matters now", subtitle: state.readiness.isReady ? "NOMINAL" : "PREFLIGHT")
            Text(priorityTitle).font(.title3.bold().monospaced()).foregroundStyle(priorityTone)
            Text(priorityDetail).font(.footnote).foregroundStyle(FieldTheme.dim)
        }.fieldPanel()
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 9) {
            FieldHeader(title: "Field actions")
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                Button { state.selectedTab = .map } label: { Label("MAP", systemImage: "map") }
                Button { state.selectedTab = .route } label: { Label("ROUTE", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
                NavigationLink(value: AppModule.navigation) { Label("NAV", systemImage: "location.north") }
                NavigationLink(value: AppModule.returnFunctions) { Label("RETURN", systemImage: "arrow.uturn.backward") }
                NavigationLink(value: AppModule.lost) { Label("LOST", systemImage: "questionmark.diamond") }
                NavigationLink(value: AppModule.emergency) { Label("SOS", systemImage: "sos") }.tint(FieldTheme.danger)
            }.buttonStyle(TerminalButtonStyle())
        }.fieldPanel()
    }

    private var routePanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            FieldHeader(title: "Route", subtitle: state.activeRoute == nil ? "NO ACTIVE ROUTE" : "ACTIVE")
            if let route = state.activeRoute {
                let m = RouteEngine.metrics(for: route)
                Text(route.name).font(.headline.bold().monospaced()).foregroundStyle(FieldTheme.text)
                HStack(spacing: 8) {
                    MetricTile(label: "DIST", value: String(format: "%.1f mi", m.distanceMiles))
                    MetricTile(label: "GAIN", value: String(format: "%.0f ft", m.ascentFeet))
                    MetricTile(label: "ETA", value: m.estimatedSeconds.fieldDuration)
                }
            } else { Text("Plan or import a route to enable route recovery, ETA and navigation guidance.").font(.footnote).foregroundStyle(FieldTheme.dim) }
        }.fieldPanel()
    }

    private var devicePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldHeader(title: "Native services")
            StatusRow(title: "iPhone location", detail: location.location == nil ? "No fix" : "Live", good: location.location != nil)
            StatusRow(title: "Bluetooth", detail: mesh.bluetoothState == .poweredOn ? "Available" : "Unavailable", good: mesh.bluetoothState == .poweredOn)
            StatusRow(title: "Offline data", detail: "\(state.mapPacks.count) packs // \(state.offlinePOIs.count) POIs", good: !state.mapPacks.isEmpty || !state.offlinePOIs.isEmpty)
        }.fieldPanel()
    }

    private struct PriorityItem {
        var score: Int
        var title: String
        var detail: String
        var tone: Color
    }

    private var priority: PriorityItem {
        var items: [PriorityItem] = []
        if let fix = location.location {
            let age = Date().timeIntervalSince(fix.timestamp)
            if age > 180 { items.append(.init(score: 100, title: "GNSS FIX STALE", detail: "Last trusted position is \(Int(age)) seconds old. Use map/compass and last known fix until GPS recovers.", tone: FieldTheme.danger)) }
            if let route = state.activeRoute, let progress = RouteEngine.progress(on: route, from: fix) {
                let offFeet = progress.nearest.distanceMeters * 3.28084
                if offFeet > 300 { items.append(.init(score: 95, title: "ROUTE DEVIATION", detail: String(format: "You are approximately %.0f ft from the active route corridor.", offFeet), tone: FieldTheme.danger)) }
                else if offFeet > 100 { items.append(.init(score: 82, title: "OFF ROUTE", detail: String(format: "You are approximately %.0f ft from the active route.", offFeet), tone: FieldTheme.amber)) }
            }
            let solar = SunService.window(for: fix.coordinate)
            if let remain = solar.daylightRemaining(), remain < 3600 { items.append(.init(score: 76, title: "DAYLIGHT ENDING SOON", detail: "Approximately \(Int(remain / 60)) minutes remain until calculated sunset.", tone: FieldTheme.amber)) }
        } else { items.append(.init(score: 100, title: "ACQUIRE LOCATION FIX", detail: "FIELD/OS is waiting for a valid iPhone GPS position.", tone: FieldTheme.danger)) }
        if let battery = sensor.snapshot.batteryPercent {
            if battery <= 15 { items.append(.init(score: 92, title: "CRITICAL BATTERY", detail: "Phone battery is \(battery)%. Preserve navigation and communications power.", tone: FieldTheme.danger)) }
            else if battery <= 25 { items.append(.init(score: 72, title: "LOW BATTERY", detail: "Phone battery is \(battery)%. Consider low-power mode before reserve becomes critical.", tone: FieldTheme.amber)) }
        }
        if let due = checkIn.nextDue {
            let left = due.timeIntervalSinceNow
            if left < 0 { items.append(.init(score: 88, title: "CHECK-IN OVERDUE", detail: "The scheduled field check-in is overdue.", tone: FieldTheme.danger)) }
            else if left < 600 { items.append(.init(score: 68, title: "CHECK-IN DUE SOON", detail: "A scheduled check-in is due in about \(max(1, Int(left / 60))) minutes.", tone: FieldTheme.amber)) }
        }
        if !state.readiness.routeChecked { items.append(.init(score: 55, title: "REVIEW ACTIVE ROUTE", detail: "Save and review a route before departure.", tone: FieldTheme.amber)) }
        if !state.readiness.offlineMapChecked { items.append(.init(score: 50, title: "VERIFY OFFLINE COVERAGE", detail: "Confirm the map/data needed for the trip is stored locally.", tone: FieldTheme.amber)) }
        return items.max(by: { $0.score < $1.score }) ?? .init(score: 1, title: "FIELD STATUS NOMINAL", detail: "Monitoring route, position, daylight, battery, check-in, track state and communications readiness.", tone: FieldTheme.accent)
    }

    private var priorityTitle: String { priority.title }
    private var priorityTone: Color { priority.tone }
    private var priorityDetail: String { priority.detail }
    private var altitudeText: String { location.location.map { "\(Int($0.altitude * 3.28084)) ft" } ?? "--" }
    private var accuracyText: String { location.location.map { "±\(Int(max(0,$0.horizontalAccuracy)))m" } ?? "ACC --" }
}

private struct CompactStatus: View {
    let label: String; let value: String; let good: Bool
    var body: some View { HStack(spacing: 6) { Circle().fill(good ? FieldTheme.accent : FieldTheme.amber).frame(width: 6, height: 6); VStack(alignment: .leading, spacing: 1) { Text(label).font(.caption2.monospaced()).foregroundStyle(FieldTheme.dim); Text(value).font(.caption.bold().monospaced()).lineLimit(1) } }.frame(maxWidth: .infinity, alignment: .leading).padding(9).background(FieldTheme.panel, in: RoundedRectangle(cornerRadius: 10)).overlay { RoundedRectangle(cornerRadius: 10).stroke(FieldTheme.border.opacity(0.6)) } }
}

private struct StatusRow: View {
    let title: String; let detail: String; let good: Bool
    var body: some View { HStack { Image(systemName: good ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(good ? FieldTheme.accent : FieldTheme.amber); Text(title); Spacer(); Text(detail).foregroundStyle(FieldTheme.dim) }.font(.caption.monospaced()) }
}
