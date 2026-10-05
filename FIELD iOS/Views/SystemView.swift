import SwiftUI

// Privacy-minimized diagnostics: never exports coordinates, raw packets, chat text or BLE identifiers.
private struct FieldDiagnostics: Encodable {
    let capturedAt: Date
    let nativeVersion: String
    let phoneAPILink: String
    let bluetoothPowered: Bool
    let receivedEnvelopeCount: Int
    let decodedEventCount: Int
    let rejectedEnvelopeCount: Int
    let meshNodeCount: Int
    let storedMapPackCount: Int
    let storedRouteCount: Int
    let savedLocalStateAt: Date?
    let saveError: String?
}

struct SystemView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var mesh: MeshService
    @EnvironmentObject private var sensor: SensorService
    @State private var exportURL: URL?
    @State private var showingReset = false
    @State private var diagnosticsURL: URL?
    @State private var exportError: String?

    var body: some View {
        Form {
            Section("Preflight") {
                status("Location permission", location.authorizationStatus == .authorizedWhenInUse || location.authorizationStatus == .authorizedAlways)
                status("Fresh GPS fix", location.location.map {
                    $0.horizontalAccuracy >= 0 && (0...180).contains(Date().timeIntervalSince($0.timestamp))
                } ?? false)
                status("Active route", (state.activeRoute?.points.count ?? 0) >= 2)
                status("Readiness checklist", state.readiness.isReady)
                status("Bluetooth available", mesh.bluetoothState == .poweredOn)
                status("Battery visible", sensor.snapshot.batteryPercent != nil)
                LabeledContent("PMTiles rendering", value: "NOT IMPLEMENTED")
                status("PMTiles archive imported", !state.mapPacks.isEmpty)
                status("Offline POI index", !state.offlinePOIs.isEmpty)
            }
            Section("Field UI") {
                Toggle("Offline mode", isOn: $state.settings.offlineMode)
                Toggle("Glove mode", isOn: $state.settings.gloveMode)
                Toggle("One-handed controls", isOn: $state.settings.oneHandedControls)
                Toggle("High accuracy GPS", isOn: $state.settings.highAccuracyGPS)
                Toggle("Automatic recovery snapshots", isOn: $state.settings.autoRecoverySnapshots)
            }
            Section("Meshtastic diagnostics") {
                LabeledContent("PhoneAPI link", value: mesh.linkState.rawValue)
                LabeledContent("BLE frames", value: "\(mesh.receivedEnvelopeCount)")
                LabeledContent("Decoded events", value: "\(mesh.decodedCount)")
                LabeledContent("Rejected frames", value: "\(mesh.decodeFailures)")
                LabeledContent("Actual mesh nodes", value: "\(mesh.meshNodes.count)")
                Text("BLE acknowledgement does not verify mesh delivery. TAP V2 and satellite hardware remain unverified.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Data resilience") {
                LabeledContent("Recovery status", value: state.lastRecoveryStatus)
                if let saveError = state.lastSaveError { Text(saveError).foregroundStyle(FieldTheme.amber) }
                if let saved = state.lastSavedAt { LabeledContent("Last saved", value: saved.formatted(date: .abbreviated, time: .shortened)) }
                Button("Export Private-Free Diagnostics") { Task { await exportDiagnostics() } }
                if let diagnosticsURL { ShareLink(item: diagnosticsURL) { Label("Share Diagnostic JSON", systemImage: "square.and.arrow.up") } }
                if let exportError { Text(exportError).foregroundStyle(FieldTheme.amber) }
                Button("Save Recovery Snapshot") { state.persist() }
                Button("Prepare Export Snapshot") { Task { exportURL = try? await OfflineStore.shared.exportSnapshot(state.snapshot(), prefix: "FIELD-OS-backup") } }
                if let exportURL { ShareLink(item: exportURL) { Label("Share Full Backup JSON (includes coordinates/messages)", systemImage: "square.and.arrow.up") } }
            }
            Section("App") {
                LabeledContent("Version", value: "0.8-native")
                LabeledContent("Web reference", value: "FIELD/OS 3.82")
                Text("The native project is intentionally separate from the web repository and does not modify its files.").font(.caption).foregroundStyle(.secondary)
            }
            Section { Button("Clear Native Local Data", role: .destructive) { showingReset = true } }
        }
        .scrollContentBackground(.hidden)
        .background(FieldTheme.background.ignoresSafeArea())
        .tint(FieldTheme.accent)
        .environment(\.defaultMinListRowHeight, 46)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("System")
        .onChange(of: state.settings) { _, _ in state.persist() }
        .alert("Clear native local data?", isPresented: $showingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { Task { await state.clearLocalData() } }
        } message: { Text("This does not touch the separate web app or GitHub repository.") }
    }

    @MainActor private func exportDiagnostics() async {
        let report = FieldDiagnostics(capturedAt: .now, nativeVersion: "0.8",
                                      phoneAPILink: mesh.linkState.rawValue,
                                      bluetoothPowered: mesh.bluetoothState == .poweredOn,
                                      receivedEnvelopeCount: mesh.receivedEnvelopeCount,
                                      decodedEventCount: mesh.decodedCount,
                                      rejectedEnvelopeCount: mesh.decodeFailures,
                                      meshNodeCount: mesh.meshNodes.count,
                                      storedMapPackCount: state.mapPacks.count,
                                      storedRouteCount: state.savedRoutes.count,
                                      savedLocalStateAt: state.lastSavedAt,
                                      saveError: state.lastSaveError)
        do { diagnosticsURL = try await OfflineStore.shared.exportSnapshot(report, prefix: "FIELD-OS-diagnostics") }
        catch { exportError = error.localizedDescription }
    }

    private func status(_ name: String, _ ok: Bool) -> some View {
        HStack { Text(name); Spacer(); Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(ok ? FieldTheme.accent : FieldTheme.amber) }
    }
}
