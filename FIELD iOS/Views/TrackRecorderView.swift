import SwiftUI

struct TrackRecorderView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var track: TrackRecorder
    @State private var saveName = "RECORDED TRACK"

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    FieldHeader(title: "Track recorder", subtitle: track.state.rawValue)
                    HStack(spacing: 8) {
                        MetricTile(label: "Time", value: track.elapsed.fieldDuration)
                        MetricTile(label: "Distance", value: String(format: "%.2f mi", track.distanceMeters / 1609.344))
                        MetricTile(label: "Points", value: "\(track.points.count)")
                    }
                    HStack(spacing: 8) {
                        MetricTile(label: "Gain", value: String(format: "%.0f ft", track.ascentMeters * 3.28084))
                        MetricTile(label: "Max speed", value: String(format: "%.1f mph", track.maxSpeedMPS * 2.23694))
                    }
                }.fieldPanel()
                controlPanel
                savePanel
            }.padding(14)
        }.background(FieldTheme.background).navigationTitle("Track Recorder")
    }

    private var controlPanel: some View {
        HStack {
            if track.state == .stopped { Button("START") { track.start() } }
            if track.state == .recording { Button("PAUSE") { track.pause() }; Button("STOP") { track.stop() } }
            if track.state == .paused { Button("RESUME") { track.resume() }; Button("STOP") { track.stop() } }
            Button("RESET", role: .destructive) { track.reset() }
        }.buttonStyle(TerminalButtonStyle()).fieldPanel()
    }

    private var savePanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            FieldHeader(title: "Save breadcrumb")
            TextField("Track name", text: $saveName).textFieldStyle(.roundedBorder)
            Button("SAVE AS ACTIVE ROUTE") {
                var route = track.route(name: saveName)
                route.terrain = .maintained
                state.saveRoute(route)
                state.log("TRACK", "Saved breadcrumb with \(track.points.count) points")
            }.buttonStyle(TerminalButtonStyle()).disabled(track.points.count < 2)
        }.fieldPanel()
    }
}
