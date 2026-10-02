import CoreLocation
import Foundation

struct SolarWindow: Equatable {
    var sunrise: Date?
    var sunset: Date?

    func daylightRemaining(from date: Date = .now) -> TimeInterval? {
        guard let sunset, sunset > date else { return nil }
        return sunset.timeIntervalSince(date)
    }
}

enum SunService {
    static func window(for coordinate: CLLocationCoordinate2D, date: Date = .now, calendar: Calendar = .current) -> SolarWindow {
        // NOAA-style approximation. Accurate enough for field planning, but not a substitute for official almanac data.
        let start = calendar.startOfDay(for: date)
        let day = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let lngHour = coordinate.longitude / 15.0
        return SolarWindow(
            sunrise: event(start: start, day: day, latitude: coordinate.latitude, lngHour: lngHour, sunrise: true, calendar: calendar),
            sunset: event(start: start, day: day, latitude: coordinate.latitude, lngHour: lngHour, sunrise: false, calendar: calendar)
        )
    }

    private static func event(start: Date, day: Double, latitude: Double, lngHour: Double, sunrise: Bool, calendar: Calendar) -> Date? {
        let zenith = 90.833
        let t = day + ((sunrise ? 6.0 : 18.0) - lngHour) / 24.0
        let m = (0.9856 * t) - 3.289
        var l = m + 1.916 * sin(m.radians) + 0.020 * sin((2 * m).radians) + 282.634
        l = normalized(l, max: 360)
        var ra = atan(0.91764 * tan(l.radians)).degrees
        ra = normalized(ra, max: 360)
        let lQuadrant = floor(l / 90) * 90
        let raQuadrant = floor(ra / 90) * 90
        ra = (ra + lQuadrant - raQuadrant) / 15
        let sinDec = 0.39782 * sin(l.radians)
        let cosDec = cos(asin(sinDec))
        let cosH = (cos(zenith.radians) - sinDec * sin(latitude.radians)) / (cosDec * cos(latitude.radians))
        guard cosH >= -1, cosH <= 1 else { return nil }
        var h = sunrise ? 360 - acos(cosH).degrees : acos(cosH).degrees
        h /= 15
        let localMean = h + ra - (0.06571 * t) - 6.622
        let utcHours = normalized(localMean - lngHour, max: 24)
        let utcStart = Calendar(identifier: .gregorian).date(bySettingHour: 0, minute: 0, second: 0, of: start) ?? start
        let eventUTC = utcStart.addingTimeInterval(utcHours * 3600)
        // start is local midnight. Rebuild the event from UTC components to avoid assuming the current zone offset is constant.
        let utc = Calendar(identifier: .gregorian)
        let components = utc.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: eventUTC)
        return calendar.date(from: DateComponents(timeZone: TimeZone(secondsFromGMT: 0), year: components.year, month: components.month, day: components.day, hour: components.hour, minute: components.minute, second: components.second))
    }

    private static func normalized(_ value: Double, max: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: max)
        return result < 0 ? result + max : result
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
