import SwiftUI

// The home screen is a fast, native field console. The contour artwork is
// decorative, never presented as a geographic map or as offline coverage.
// Actual maps initialize only after the user enters the Map tab.
struct DashboardView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var sensor: SensorService
    @EnvironmentObject private var mesh: MeshService
    @EnvironmentObject private var track: TrackRecorder
    @EnvironmentObject private var checkIn: CheckInService

    @State private var showReadiness = false
    @State private var showDiagnostics = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    consoleHeader
                    liveStatusStrip
                    terrainEntry
                    priorityCard
                    actionGrid
                    activeRouteCard
                    readinessCard
                    diagnosticsCard
                    Text("FIELD / OS  •  NATIVE FIELD CONSOLE")
                        .font(.caption2.monospaced())
                        .tracking(1)
                        .foregroundStyle(FieldTheme.dim.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
            .background(FieldTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("FIELD / OS")
                        .font(.subheadline.bold().monospaced())
                        .tracking(2)
                        .foregroundStyle(FieldTheme.text)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        state.settings.offlineMode.toggle()
                        state.persist()
                    } label: {
                        Image(systemName: state.settings.offlineMode ? "wifi.slash" : "wifi")
                            .font(.subheadline.bold())
                            .frame(width: 44, height: 42)
                    }
                    .tint(state.settings.offlineMode ? FieldTheme.amber : FieldTheme.accent)
                    .accessibilityLabel(state.settings.offlineMode ? "Disable offline mode" : "Enable offline mode")
                }
            }
            .navigationDestination(for: AppModule.self) { ModuleDestination(module: $0) }
        }
    }

    private var consoleHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TAP V2  /  EXPEDITION CONSOLE")
                    .font(.caption2.bold().monospaced())
                    .tracking(1.25)
                    .foregroundStyle(FieldTheme.dim)
                Text("YOUR FIELD,\nAT A GLANCE.")
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .tracking(0.25)
                    .lineSpacing(0)
                    .foregroundStyle(FieldTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 8) {
                StatusPill(text: state.settings.offlineMode ? "OFFLINE" : "LOCAL",
                           tone: state.settings.offlineMode ? FieldTheme.amber : FieldTheme.accent)
                Text(Date.now, format: .dateTime.hour().minute())
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(FieldTheme.dim)
            }
        }
    }

    private var liveStatusStrip: some View {
        HStack(spacing: 0) {
            ConsoleStatus(symbol: "location.fill", title: "GPS",
                          value: gpsValue, tone: gpsTone)
            Rectangle().fill(FieldTheme.border.opacity(0.5))
                .frame(width: 1, height: 28)
            ConsoleStatus(symbol: "dot.radiowaves.left.and.right", title: "MESH",
                          value: meshValue, tone: mesh.linkState == .connected ? FieldTheme.accent : FieldTheme.amber)
            Rectangle().fill(FieldTheme.border.opacity(0.5))
                .frame(width: 1, height: 28)
            ConsoleStatus(symbol: "figure.hiking", title: "TRACK",
                          value: track.state.rawValue.uppercased(),
                          tone: track.state == .recording ? FieldTheme.accent : FieldTheme.dim)
        }
        .padding(.vertical, 12)
        .background(FieldTheme.panel, in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(FieldTheme.border.opacity(0.55), lineWidth: 1)
        }
    }

    private var terrainEntry: some View {
        Button {
            state.selectedTab = .map
        } label: {
            ZStack(alignment: .topLeading) {
                TopographicLines()
                    .allowsHitTesting(false)
                LinearGradient(colors: [FieldTheme.panel, FieldTheme.panel.opacity(0.87), .clear],
                               startPoint: .leading, endPoint: .trailing)
                VStack(alignment: .leading, spacing: 10) {
                    Label("TERRAIN / NAVIGATION", systemImage: "mountain.2")
                        .font(.caption2.bold().monospaced())
                        .tracking(1.2)
                        .foregroundStyle(FieldTheme.accent)
                    Spacer(minLength: 8)
                    Text("OPEN THE MAP")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(FieldTheme.text)
                    Text(mapEntrySubtitle)
                        .font(.caption.monospaced())
                        .foregroundStyle(FieldTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 5) {
                        Text("EXPLORE TERRAIN")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.caption.bold().monospaced())
                    .foregroundStyle(FieldTheme.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(FieldTheme.accent, in: Capsule())
                }
                .padding(17)
            }
            .frame(maxWidth: .infinity, minHeight: 185, maxHeight: 210, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(FieldTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open terrain map. " + mapEntrySubtitle)
    }

    private var priorityCard: some View {
        let current = priority
        return HStack(alignment: .top, spacing: 11) {
            Image(systemName: current.symbol)
                .font(.headline)
                .foregroundStyle(current.tone)
                .frame(width: 32, height: 32)
                .background(current.tone.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("WHAT MATTERS NOW")
                        .font(.caption2.bold().monospaced())
                        .tracking(0.8)
                        .foregroundStyle(FieldTheme.dim)
                    Spacer(minLength: 4)
                    Text(current.category)
                        .font(.caption2.bold().monospaced())
                        .foregroundStyle(current.tone)
                }
                Text(current.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(FieldTheme.text)
                Text(current.detail)
                    .font(.caption)
                    .foregroundStyle(FieldTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fieldPanel()
    }

    private var actionGrid: some View {
        VStack(alignment: .leading, spacing: 9) {
            FieldHeader(title: "Quick actions", subtitle: "READY WHEN YOU ARE")
            HStack(spacing: 9) {
                Button { state.selectedTab = .route } label: {
                    FieldActionLabel(symbol: "point.topleft.down.to.point.bottomright.curvepath",
                                     title: "PLAN ROUTE", subtitle: "Snap & save")
                }
                NavigationLink(value: AppModule.navigation) {
                    FieldActionLabel(symbol: "location.north.line.fill",
                                     title: "NAVIGATE", subtitle: "Follow a route")
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 9) {
                NavigationLink(value: AppModule.returnFunctions) {
                    FieldActionLabel(symbol: "arrow.uturn.backward",
                                     title: "RETURN", subtitle: "Backtrack tools")
                }
                NavigationLink(value: AppModule.emergency) {
                    FieldActionLabel(symbol: "cross.circle",
                                     title: "SOS TOOLS", subtitle: "Emergency options",
                                     tone: FieldTheme.danger)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var activeRouteCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            FieldHeader(title: "Active route", subtitle: state.activeRoute == nil ? "NOT SET" : "LOADED")
            if let route = state.activeRoute {
                let metrics = RouteEngine.metrics(for: route)
                Text(route.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(FieldTheme.text)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    MetricTile(label: "DISTANCE", value: String(format: "%.1f mi", metrics.distanceMiles))
                    MetricTile(label: "ASCENT", value: String(format: "%.0f ft", metrics.ascentFeet))
                    MetricTile(label: "EST. TIME", value: metrics.estimatedSeconds.fieldDuration)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.title2)
                        .foregroundStyle(FieldTheme.dim)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No route loaded")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FieldTheme.text)
                        Text("Create or import a route for distance, ascent and ETA.")
                            .font(.caption)
                            .foregroundStyle(FieldTheme.dim)
                    }
                    Spacer(minLength: 2)
                    Button {
                        state.selectedTab = .route
                    } label: {
                        Image(systemName: "arrow.right")
                            .frame(width: 44, height: 44)
                            .background(FieldTheme.panelRaised, in: Circle())
                    }
                    .accessibilityLabel("Plan a route")
                }
            }
        }
        .fieldPanel()
    }

    private var readinessCard: some View {
        DisclosureGroup(isExpanded: $showReadiness) {
            ReadinessView()
                .padding(.top, 12)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("PREFLIGHT CHECKLIST")
                        .font(.caption.bold().monospaced())
                        .tracking(0.7)
                        .foregroundStyle(FieldTheme.text)
                    Spacer()
                    Text("\(state.readiness.completedCount)/\(state.readiness.totalCount) DONE")
                        .font(.caption2.bold().monospaced())
                        .foregroundStyle(FieldTheme.accent)
                }
                ProgressView(value: Double(state.readiness.completedCount),
                             total: Double(max(1, state.readiness.totalCount)))
                    .tint(FieldTheme.accent)
                    .accessibilityLabel("Readiness checklist progress")
            }
        }
        .tint(FieldTheme.accent)
        .fieldPanel()
    }

    private var diagnosticsCard: some View {
        DisclosureGroup(isExpanded: $showDiagnostics) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    MetricTile(label: "ALTITUDE", value: altitudeText, detail: accuracyText)
                    MetricTile(label: "BATTERY", value: batteryText,
                               detail: sensor.snapshot.lowPowerMode ? "LOW POWER" : "IPHONE")
                }
                Divider().overlay(FieldTheme.border)
                DiagnosticRow(symbol: "location", title: "iPhone location",
                              detail: gpsValue, tone: gpsTone)
                DiagnosticRow(symbol: "dot.radiowaves.left.and.right", title: "Mesh link",
                              detail: meshValue,
                              tone: mesh.linkState == .connected ? FieldTheme.accent : FieldTheme.dim)
                DiagnosticRow(symbol: "square.stack.3d.up", title: "Offline map packs",
                              detail: "\(state.mapPacks.count) imported",
                              tone: state.mapPacks.contains(where: { $0.active }) ? FieldTheme.accent : FieldTheme.amber)
                NavigationLink(value: AppModule.lost) {
                    Label("Lost / recovery guidance", systemImage: "questionmark.diamond")
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
            }
            .padding(.top, 12)
        } label: {
            Label("SENSORS & DIAGNOSTICS", systemImage: "waveform.path.ecg")
                .font(.caption.bold().monospaced())
                .tracking(0.6)
                .foregroundStyle(FieldTheme.text)
        }
        .tint(FieldTheme.accent)
        .fieldPanel()
    }

    private var gpsValue: String {
        guard let fix = location.location, fix.horizontalAccuracy >= 0 else { return "SEARCHING" }
        return Date().timeIntervalSince(fix.timestamp) > 120 ? "STALE" : "FIX"
    }
    private var gpsTone: Color {
        switch gpsValue {
        case "FIX": return FieldTheme.accent
        case "STALE": return FieldTheme.danger
        default: return FieldTheme.amber
        }
    }
    private var meshValue: String {
        switch mesh.linkState {
        case .connected: return "LINKED"
        case .scanning: return "SCANNING"
        case .connecting, .syncing: return "SYNCING"
        default: return "IDLE"
        }
    }
    private var mapEntrySubtitle: String {
        state.mapPacks.contains(where: { $0.active })
            ? "LOCAL PACK ACTIVE  /  VIEW COVERAGE"
            : "LIVE TERRAIN  /  IMPORT MAPS FOR OFFLINE"
    }
    private var batteryText: String {
        sensor.snapshot.batteryPercent.map { "\($0)%" } ?? "—"
    }
    private var altitudeText: String {
        location.location.map { "\(Int($0.altitude * 3.28084)) ft" } ?? "—"
    }
    private var accuracyText: String {
        location.location.map { "±\(Int(max(0, $0.horizontalAccuracy)))m" } ?? "NO FIX"
    }

    private struct PriorityItem {
        let severity: Int
        let category: String
        let title: String
        let detail: String
        let tone: Color
        let symbol: String
    }

    private var priority: PriorityItem {
        var alerts: [PriorityItem] = []
        if let fix = location.location, fix.horizontalAccuracy >= 0 {
            if Date().timeIntervalSince(fix.timestamp) > 180 {
                alerts.append(.init(severity: 100, category: "POSITION", title: "GPS position is stale",
                                    detail: "Your last known location is old. Verify it before following route guidance.",
                                    tone: FieldTheme.danger, symbol: "location.slash"))
            }
            if let route = state.activeRoute,
               let progress = RouteEngine.progress(on: route, from: fix) {
                let feet = progress.nearest.distanceMeters * 3.28084
                if feet > 300 {
                    alerts.append(.init(severity: 95, category: "NAVIGATION", title: "Far from the route",
                                        detail: String(format: "Your last fix is approximately %.0f ft from the route.", feet),
                                        tone: FieldTheme.danger, symbol: "point.topleft.down.to.point.bottomright.curvepath"))
                } else if feet > 100 {
                    alerts.append(.init(severity: 82, category: "NAVIGATION", title: "Check your route",
                                        detail: String(format: "Your last fix is approximately %.0f ft off the route.", feet),
                                        tone: FieldTheme.amber, symbol: "point.topleft.down.to.point.bottomright.curvepath"))
                }
            }
            if let remaining = SunService.window(for: fix.coordinate).daylightRemaining(),
               remaining < 3600 {
                alerts.append(.init(severity: 76, category: "DAYLIGHT", title: "Sunset approaching",
                                    detail: "Calculated sunset in approximately \(Int(remaining / 60)) minutes. Verify conditions.",
                                    tone: FieldTheme.amber, symbol: "sunset"))
            }
        } else {
            alerts.append(.init(severity: 55, category: "LOCATION", title: "Waiting for GPS",
                                detail: "Grant location permission to enable navigation and position tracking.",
                                tone: FieldTheme.amber, symbol: "location"))
        }
        if let battery = sensor.snapshot.batteryPercent {
            if battery <= 15 {
                alerts.append(.init(severity: 92, category: "POWER", title: "Critical battery",
                                    detail: "Phone battery is \(battery)%. Preserve navigation and communication power.",
                                    tone: FieldTheme.danger, symbol: "battery.25percent"))
            } else if battery <= 25 {
                alerts.append(.init(severity: 72, category: "POWER", title: "Low battery",
                                    detail: "Phone battery is \(battery)%. Consider power-saving measures.",
                                    tone: FieldTheme.amber, symbol: "battery.25percent"))
            }
        }
        if let due = checkIn.nextDue {
            let remaining = due.timeIntervalSinceNow
            if remaining < 0 {
                alerts.append(.init(severity: 88, category: "CHECK-IN", title: "Check-in overdue",
                                    detail: "Scheduled check-in time has passed.",
                                    tone: FieldTheme.danger, symbol: "bell.badge"))
            } else if remaining < 600 {
                alerts.append(.init(severity: 68, category: "CHECK-IN", title: "Check-in soon",
                                    detail: "Check-in due in about \(max(1, Int(remaining / 60))) minutes.",
                                    tone: FieldTheme.amber, symbol: "bell"))
            }
        }
        if !state.readiness.routeChecked {
            alerts.append(.init(severity: 40, category: "PREFLIGHT", title: "Review your planned route",
                                detail: "Load a route and confirm it before departure.",
                                tone: FieldTheme.amber, symbol: "list.bullet.clipboard"))
        }
        if !state.readiness.offlineMapChecked {
            alerts.append(.init(severity: 35, category: "PREFLIGHT", title: "Verify offline coverage",
                                detail: "Import and test an offline basemap for your trip.",
                                tone: FieldTheme.amber, symbol: "square.stack.3d.up"))
        }
        return alerts.max(by: { $0.severity < $1.severity }) ??
            .init(severity: 0, category: "PREFLIGHT", title: "Checklist complete",
                  detail: "Continue monitoring the actual weather, route and equipment.",
                  tone: FieldTheme.accent, symbol: "checkmark.shield")
    }
}

private struct ConsoleStatus: View {
    let symbol: String
    let title: String
    let value: String
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.caption2)
                Text(title).font(.caption2.bold().monospaced()).tracking(0.5)
            }
            .foregroundStyle(FieldTheme.dim)
            HStack(spacing: 5) {
                Circle().fill(tone).frame(width: 5, height: 5)
                Text(value)
                    .font(.caption.bold().monospaced())
                    .foregroundStyle(FieldTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
    }
}

private struct TopographicLines: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<9 {
                let ring = CGFloat(index)
                let rect = CGRect(x: size.width * 0.49 - ring * 25,
                                  y: -size.height * 0.42 + ring * 11,
                                  width: size.width * 0.79 + ring * 44,
                                  height: size.height * 1.22 + ring * 35)
                let path = Path(ellipseIn: rect)
                context.stroke(path, with: .color(FieldTheme.accent.opacity(index.isMultiple(of: 3) ? 0.28 : 0.13)),
                               lineWidth: 1)
            }
            let cross = CGPoint(x: size.width * 0.79, y: size.height * 0.54)
            var crosshair = Path()
            crosshair.move(to: CGPoint(x: cross.x - 10, y: cross.y))
            crosshair.addLine(to: CGPoint(x: cross.x + 10, y: cross.y))
            crosshair.move(to: CGPoint(x: cross.x, y: cross.y - 10))
            crosshair.addLine(to: CGPoint(x: cross.x, y: cross.y + 10))
            context.stroke(crosshair, with: .color(FieldTheme.accent.opacity(0.75)), lineWidth: 1)
        }
        .background(FieldTheme.panelRaised.opacity(0.68))
        .accessibilityHidden(true)
    }
}

private struct FieldActionLabel: View {
    let symbol: String
    let title: String
    let subtitle: String
    var tone: Color = FieldTheme.accent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tone)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.bold().monospaced())
                    .foregroundStyle(FieldTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.83)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(FieldTheme.dim)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(FieldTheme.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(tone.opacity(0.45), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

private struct DiagnosticRow: View {
    let symbol: String
    let title: String
    let detail: String
    let tone: Color

    var body: some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(tone)
                .frame(width: 24)
            Text(title).foregroundStyle(FieldTheme.text)
            Spacer(minLength: 5)
            Text(detail).foregroundStyle(FieldTheme.dim)
        }
        .font(.caption.monospaced())
    }
}
