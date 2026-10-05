import SwiftUI
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

struct WeatherView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var location: LocationService
    @State private var isLoading = false
    @State private var fetchError: String?
    #if canImport(WeatherKit)
    @State private var attribution: WeatherAttribution?
    #endif

    private var fixIsFresh: Bool {
        guard let fix = location.location else { return false }
        return fix.horizontalAccuracy >= 0 && fix.horizontalAccuracy <= 1000
            && (0...180).contains(Date().timeIntervalSince(fix.timestamp))
    }
    var body: some View {
        VStack(spacing: 0) {
            SecondaryConsoleTitle(title: "WEATHER STATION",
                                  status: state.settings.offlineMode ? "OFFLINE" : "LIVE CAPABLE",
                                  symbol: "cloud.sun")
            ScrollView {
                VStack(spacing: 10) {
                    SecondaryConsolePanel(title: "Field forecast",
                                          detail: state.weather.source) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text(state.weather.summary)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(FieldTheme.text)
                            HStack(spacing: 7) {
                                MetricTile(label: "TEMPERATURE",
                                           value: state.weather.temperatureC.map {
                                               String(format: "%.1f°C", $0)
                                           } ?? "--")
                                MetricTile(label: "WIND",
                                           value: state.weather.windKPH.map {
                                               String(format: "%.0f km/h", $0)
                                           } ?? "--")
                            }
                            if let updated = state.weather.updatedAt {
                                Text("LAST READING: " + updated.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(FieldTheme.dim)
                            } else {
                                Text("NO LIVE FORECAST LOADED")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(FieldTheme.amber)
                            }
                            if !state.weather.alerts.isEmpty {
                                Label("Weather alerts exist. Review official alert details.",
                                      systemImage: "exclamationmark.triangle")
                                    .font(.caption.monospaced()).foregroundStyle(FieldTheme.amber)
                            }
                        }
                    }
                    SecondaryConsolePanel(title: "Live provider", detail: "APPLE WEATHER") {
                        VStack(alignment: .leading, spacing: 10) {
                            Button(isLoading ? "FETCHING…" : "REFRESH USING DEVICE GPS") {
                                Task { await refresh() }
                            }
                            .buttonStyle(SecondaryConsoleButton(emphasized: true))
                            .disabled(isLoading || !fixIsFresh || state.settings.offlineMode)
                            if !fixIsFresh {
                                Label("A fresh GPS fix is required before refreshing.",
                                      systemImage: "location.slash")
                                    .foregroundStyle(FieldTheme.amber)
                            }
                            if state.settings.offlineMode {
                                Text("OFFLINE MODE: LIVE WEATHER DISABLED")
                                    .foregroundStyle(FieldTheme.amber)
                            }
                            if let fetchError {
                                Text(fetchError).foregroundStyle(FieldTheme.amber)
                            }
                            #if canImport(WeatherKit)
                            if let attribution {
                                HStack {
                                    AsyncImage(url: attribution.combinedMarkDarkURL) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: { Text("Apple Weather") }
                                        .frame(maxWidth: 170, maxHeight: 32)
                                    Link("Data sources", destination: attribution.legalPageURL)
                                }
                            }
                            #endif
                            Toggle("WEATHER REVIEWED FOR THIS TRIP",
                                   isOn: $state.readiness.weatherChecked)
                                .tint(FieldTheme.accent)
                                .onChange(of: state.readiness.weatherChecked) { _, _ in state.persist() }
                        }
                        .font(.caption.monospaced())
                        .foregroundStyle(FieldTheme.text)
                    }
                    Text("WeatherKit requires a configured Apple entitlement and a connection. Verify forecasts with an official source before remote travel.")
                        .font(.caption2.monospaced()).foregroundStyle(FieldTheme.dim)
                }
                .padding(10)
            }
        }
        .background(FieldTheme.background.ignoresSafeArea())
        // Keep the compact iOS back affordance when opened from Tools.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor private func refresh() async {
        guard !state.settings.offlineMode, fixIsFresh, let fix = location.location else { return }
        isLoading = true; fetchError = nil
        defer { isLoading = false }
        #if canImport(WeatherKit)
        do {
            let current = try await WeatherService.shared.weather(for: fix, including: .current)
            let sourceAttribution = try await WeatherService.shared.attribution
            attribution = sourceAttribution
            state.weather = WeatherSnapshot(updatedAt: .now,
                                            source: "Apple Weather (live session only)",
                                            temperatureC: current.temperature.converted(to: .celsius).value,
                                            windKPH: current.wind.speed.converted(to: .kilometersPerHour).value,
                                            summary: String(describing: current.condition).replacingOccurrences(of: "_", with: " "),
                                            alerts: [])
            // Do not persist provider observations as a permanent offline weather data feed.
        } catch { fetchError = "Live weather unavailable: \(error.localizedDescription). Check WeatherKit entitlement, connectivity, and Apple service status." }
        #else
        fetchError = "WeatherKit is not available in this build environment."
        #endif
    }
}
