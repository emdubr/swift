import Foundation
import CoreLocation

struct RoutePoint: Codable, Equatable, Hashable, Identifiable {
    var id = UUID()
    var latitude: Double
    var longitude: Double
    var elevation: Double?
    var timestamp: Date? = nil

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }

    init(id: UUID = UUID(), latitude: Double, longitude: Double, elevation: Double? = nil, timestamp: Date? = nil) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.timestamp = timestamp
    }

    init(location: CLLocation) {
        self.init(latitude: location.coordinate.latitude,
                  longitude: location.coordinate.longitude,
                  elevation: location.verticalAccuracy >= 0 ? location.altitude : nil,
                  timestamp: location.timestamp)
    }
}

struct FieldRoute: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = "FIELD ROUTE 01"
    var points: [RoutePoint] = []
    var anchors: [RoutePoint] = []
    var notes: String = ""
    var terrain: TerrainType = .maintained
    var createdAt: Date = .now
    var updatedAt: Date = .now
}

enum TerrainType: String, Codable, CaseIterable, Identifiable {
    case maintained = "Maintained trail"
    case rough = "Rough trail"
    case offTrail = "Off trail"
    case snow = "Snow / winter"
    var id: String { rawValue }
}

enum RouteDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case moderate = "Moderate"
    case hard = "Hard"
    case extreme = "Extreme"
}

struct RouteMetrics: Codable, Equatable {
    var distanceMeters: Double = 0
    var ascentMeters: Double = 0
    var descentMeters: Double = 0
    var maxGradePercent: Double = 0
    var estimatedSeconds: Double = 0
    var difficulty: RouteDifficulty = .easy

    var distanceMiles: Double { distanceMeters / 1609.344 }
    var ascentFeet: Double { ascentMeters * 3.28084 }
}

enum WaypointKind: String, Codable, CaseIterable, Identifiable {
    case base = "Base"
    case camp = "Camp"
    case water = "Water"
    case summit = "Summit"
    case junction = "Junction"
    case bailout = "Bailout"
    case hazard = "Hazard"
    case note = "Note"
    var id: String { rawValue }
}

struct Waypoint: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var kind: WaypointKind
    var point: RoutePoint
    var note: String = ""
    var createdAt: Date = .now
}

struct TrackSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var startedAt: Date
    var endedAt: Date?
    var points: [RoutePoint]
}

struct TripPlan: Codable, Equatable {
    var name: String = "FIELD TRIP"
    var startDate: Date = .now
    var plannedDurationHours: Double = 6
    var checkInIntervalMinutes: Int = 120
    var turnaroundTime: Date = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
    var emergencyContact: String = ""
    var notes: String = ""
}

struct MissionPlan: Codable, Equatable {
    var name: String = "FIELD MISSION"
    var objective: String = ""
    var active: Bool = false
    var startedAt: Date?
    var groupTrackingEnabled: Bool = false
    var separationLimitMiles: Double = 0.5
}

enum MessageStatus: String, Codable {
    case queued, sending, radioAccepted, routingAcknowledged, sent, failed, received
    var label: String {
        switch self {
        case .queued: return "QUEUED OFFLINE"
        case .sending: return "BLE WRITE PENDING"
        case .radioAccepted: return "RADIO ACCEPTED • DELIVERY UNCONFIRMED"
        case .routingAcknowledged: return "ROUTING ACK • NOT DELIVERY PROOF"
        case .sent: return "LEGACY SENT STATUS • UNVERIFIED"
        case .failed: return "FAILED • RETRY AVAILABLE"
        case .received: return "RECEIVED"
        }
    }
}

struct FieldMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var createdAt: Date = .now
    var channel: String = "PRIMARY"
    var sender: String = "LOCAL"
    var text: String
    var outgoing: Bool = true
    var status: MessageStatus = .queued
    var transport: String? = nil
    var packetID: UInt32? = nil
    var destination: UInt32? = nil
    var lastError: String? = nil

    init(id: UUID = UUID(), createdAt: Date = .now, channel: String = "PRIMARY",
         sender: String = "LOCAL", text: String, outgoing: Bool = true,
         status: MessageStatus = .queued, transport: String? = nil,
         packetID: UInt32? = nil, destination: UInt32? = nil, lastError: String? = nil) {
        self.id = id; self.createdAt = createdAt; self.channel = channel; self.sender = sender
        self.text = text; self.outgoing = outgoing; self.status = status
        self.transport = transport; self.packetID = packetID
        self.destination = destination; self.lastError = lastError
    }
    private enum CodingKeys: String, CodingKey {
        case id, createdAt, channel, sender, text, outgoing, status, transport, packetID, destination, lastError
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        channel = try c.decodeIfPresent(String.self, forKey: .channel) ?? "PRIMARY"
        sender = try c.decodeIfPresent(String.self, forKey: .sender) ?? "LOCAL"
        text = try c.decode(String.self, forKey: .text)
        outgoing = try c.decodeIfPresent(Bool.self, forKey: .outgoing) ?? true
        status = try c.decodeIfPresent(MessageStatus.self, forKey: .status) ?? .queued
        transport = try c.decodeIfPresent(String.self, forKey: .transport)
        packetID = try c.decodeIfPresent(UInt32.self, forKey: .packetID)
        destination = try c.decodeIfPresent(UInt32.self, forKey: .destination)
        lastError = try c.decodeIfPresent(String.self, forKey: .lastError)
    }
}

struct MeshNode: Identifiable, Equatable {
    var id: UInt32
    var name: String
    var lastHeard: Date = .now
    var location: RoutePoint? = nil
    var batteryPercent: UInt32? = nil
    var voltage: Float? = nil
    var channelUtilization: Float? = nil
    var airtimeUtilization: Float? = nil
    var temperatureC: Float? = nil
    var humidity: Float? = nil
    var pressureHPa: Float? = nil
}

struct MeshPeer: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var rssi: Int
    var lastHeard: Date
    var connected: Bool = false
    var batteryPercent: Int? = nil
    var location: RoutePoint? = nil
}

struct SensorSnapshot: Codable, Equatable {
    var timestamp: Date = .now
    var altitudeMeters: Double?
    var relativeAltitudeMeters: Double?
    var pressureKPa: Double?
    var batteryPercent: Int?
    var lowPowerMode: Bool = false
}

struct WeatherSnapshot: Codable, Equatable {
    var updatedAt: Date?
    var source: String = "NO PROVIDER"
    var temperatureC: Double?
    var windKPH: Double?
    var summary: String = "No live weather provider configured."
    var alerts: [String] = []
}

struct FieldLogEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var createdAt: Date = .now
    var category: String
    var text: String
    var point: RoutePoint? = nil
}

struct OfflinePOI: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var category: String
    var point: RoutePoint
    var source: String = "LOCAL"
}

struct MapPack: Identifiable, Codable, Equatable {
    var id = UUID()
    var originalName: String
    var localFilename: String
    var sizeBytes: Int64
    var importedAt: Date = .now
    var active: Bool = false
    var sourceLayers: [String]? = nil

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

struct FieldSettings: Codable, Equatable {
    var offlineMode = false
    var gloveMode = false
    var oneHandedControls = true
    var highAccuracyGPS = true
    var autoRecoverySnapshots = true
    var mapTerrainEnabled = true
    var mapSatelliteEnabled = false
}

struct ReadinessState: Codable, Equatable {
    var navigationChecked = false
    var weatherChecked = false
    var batteryChecked = false
    var waterChecked = false
    var emergencyPlanChecked = false
    var offlineMapChecked = false
    var routeChecked = false
    var commsChecked = false

    var values: [Bool] {
        [navigationChecked, weatherChecked, batteryChecked, waterChecked,
         emergencyPlanChecked, offlineMapChecked, routeChecked, commsChecked]
    }
    var completedCount: Int { values.filter { $0 }.count }
    var totalCount: Int { values.count }
    var isReady: Bool { completedCount == totalCount }
    var score: Int { Int((Double(completedCount) / Double(totalCount)) * 100) }
}

struct AppSnapshot: Codable, Equatable {
    var activeRoute: FieldRoute?
    var savedRoutes: [FieldRoute]
    var waypoints: [Waypoint]
    var tripPlan: TripPlan
    var mission: MissionPlan
    var messages: [FieldMessage]
    var log: [FieldLogEntry]
    var pois: [OfflinePOI]
    var readiness: ReadinessState
    var settings: FieldSettings
    var scratchpad: String
    var weather: WeatherSnapshot
    var mapPacks: [MapPack]
    var trailNetwork: TrailNetwork? = nil
}


struct RouteProgress: Equatable {
    var nearest: NearestRouteResult
    var traveledMeters: Double
    var remainingMeters: Double
    var totalMeters: Double
    var progressFraction: Double
    var estimatedRemainingSeconds: Double
}

enum TerrainRiskSeverity: Int, Comparable {
    case info = 0, watch = 1, warning = 2, high = 3
    static func < (lhs: TerrainRiskSeverity, rhs: TerrainRiskSeverity) -> Bool { lhs.rawValue < rhs.rawValue }
    var label: String {
        switch self { case .info: return "INFO"; case .watch: return "WATCH"; case .warning: return "WARNING"; case .high: return "HIGH" }
    }
}

struct TerrainRiskFlag: Identifiable, Equatable {
    var id: String
    var severity: TerrainRiskSeverity
    var title: String
    var detail: String
    var evidence: String
}

struct TerrainRiskReport: Equatable {
    var confidence: Int
    var flags: [TerrainRiskFlag]
    var actionableCount: Int { flags.filter { $0.severity >= .warning }.count }
}

struct BailoutCandidate: Identifiable, Equatable {
    var id: UUID { waypoint.id }
    var waypoint: Waypoint
    var distanceMeters: Double
    var bearingDegrees: Double
}

struct NearestRouteResult: Equatable {
    var point: RoutePoint
    var segmentIndex: Int
    var distanceMeters: Double
    var bearingDegrees: Double
}
