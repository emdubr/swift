import Charts
import SwiftUI

struct ElevationProfileView: View {
    let route: FieldRoute
    private var samples: [(distance: Double, feet: Double)] {
        var result: [(Double, Double)] = [], distance = 0.0
        for (index, point) in route.points.enumerated() {
            if index > 0 { distance += RouteEngine.distanceMeters(route.points[index - 1], point) }
            if let elevation = point.elevation { result.append((distance / 1609.344, elevation * 3.28084)) }
        }
        return result
    }
    var body: some View {
        if samples.count > 1 {
            Chart(samples, id: \.distance) { sample in
                AreaMark(x: .value("Miles", sample.distance), y: .value("Feet", sample.feet)).interpolationMethod(.catmullRom)
                LineMark(x: .value("Miles", sample.distance), y: .value("Feet", sample.feet)).interpolationMethod(.catmullRom).lineStyle(.init(lineWidth: 2))
            }
            .chartXAxisLabel("MILES").chartYAxisLabel("FT")
            .frame(height: 150)
        } else {
            ContentUnavailableView("No elevation profile", systemImage: "mountain.2", description: Text("Imported GPX/trail elevation will appear here when available."))
                .frame(height: 150)
        }
    }
}
