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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    FieldHeader(title: "Weather intelligence", subtitle: state.weather.source)
                    Text(state.weather.summary).foregroundStyle(FieldTheme.text)
                    if let updated = state.weather.updatedAt {
                        Text("Updated \(updated.formatted(date: .abbreviated, time: .shortened)) • \(Int(max(0, Date().timeIntervalSince(updated) / 60))) minutes old")
                            .font(.caption).foregroundStyle(FieldTheme.dim)
                    }
                    if let temp = state.weather.temperatureC { Text(String(format: "Temperature %.1f°C", temp)).font(.headline.monospaced()) }
                    if let wind = state.weather.windKPH { Text(String(format: "Wind %.0f km/h", wind)).font(.headline.monospaced()) }
                    if !state.weather.alerts.isEmpty { Text("Alert details unavailable in this view. Check your official forecast.").foregroundStyle(FieldTheme.amber) }
                }.fieldPanel()
                VStack(alignment: .leading, spacing: 9) {
                    FieldHeader(title: "Apple Weather live fetch")
                    Button(isLoading ? "FETCHING…" : "REFRESH USING MY GPS") { Task { await refresh() } }
                        .buttonStyle(.borderedProminent).disabled(isLoading || !fixIsFresh || state.settings.offlineMode)
                    if !fixIsFresh { Text("Fresh and accurate GPS required (less than 3 minutes old).") }
                    if state.settings.offlineMode { Text("Offline mode: online weather fetching is disabled.") }
                    if let fetchError { Text(fetchError).foregroundStyle(FieldTheme.amber) }
                    #if canImport(WeatherKit)
                    if let attribution {
                        HStack {
                            AsyncImage(url: attribution.combinedMarkDarkURL) { image in image.resizable().scaledToFit() } placeholder: { Text("Apple Weather") }
                                .frame(maxWidth: 170, maxHeight: 32)
                            Link("Weather data sources", destination: attribution.legalPageURL)
                                .font(.caption)
                        }
                    }
                    #endif
                    Text("Online WeatherKit access requires a configured Apple developer entitlement. WeatherKit data is not retained as a permanent offline database; verify forecasts and alerts with an official source before remote travel.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Weather reviewed for this trip", isOn: $state.readiness.weatherChecked)
                        .onChange(of: state.readiness.weatherChecked) { _, _ in state.persist() }
                }.fieldPanel()
            }.padding(14)
        }.background(FieldTheme.background).navigationTitle("Weather")
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
