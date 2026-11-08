import Foundation
import HueBoardKit

public struct BridgeProfile: Codable, Equatable, Identifiable, Sendable {
    public let bridgeID: String
    public let host: String
    public let port: Int
    public let modelID: String?
    public let apiVersion: String?
    public let certificateSHA256: String?

    public var id: String { bridgeID }
    public var displayHost: String { port == 443 ? host : "\(host):\(port)" }
    public var displayCertificateSHA256: String? {
        HueBridgeTLSIdentity.displaySHA256(certificateSHA256)
    }

    public init(
        bridgeID: String,
        host: String,
        port: Int = 443,
        modelID: String? = nil,
        apiVersion: String? = nil,
        certificateSHA256: String? = nil
    ) throws {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard HueBridgeHostValidator.isAllowed(normalizedHost) else {
            throw HueBoardError.network(
                "Use a private LAN IPv4 address or trusted .local Hue Bridge hostname."
            )
        }
        guard let normalizedBridgeID = HueBridgeTLSIdentity.normalizeBridgeID(bridgeID) else {
            throw HueBoardError.invalidResponse(
                "Hue Bridge IDs must contain exactly 16 hexadecimal characters."
            )
        }
        let normalizedFingerprint = certificateSHA256.flatMap(HueBridgeTLSIdentity.normalizeSHA256)
        if certificateSHA256 != nil, normalizedFingerprint == nil {
            throw HueBoardError.invalidResponse("The saved Bridge certificate fingerprint is invalid.")
        }
        self.bridgeID = normalizedBridgeID
        self.host = normalizedHost
        self.port = min(max(port, 1), 65_535)
        self.modelID = modelID
        self.apiVersion = apiVersion
        self.certificateSHA256 = normalizedFingerprint
    }

    private enum CodingKeys: String, CodingKey {
        case bridgeID, host, port, modelID, apiVersion, certificateSHA256
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            bridgeID: container.decode(String.self, forKey: .bridgeID),
            host: container.decode(String.self, forKey: .host),
            port: container.decodeIfPresent(Int.self, forKey: .port) ?? 443,
            modelID: container.decodeIfPresent(String.self, forKey: .modelID),
            apiVersion: container.decodeIfPresent(String.self, forKey: .apiVersion),
            certificateSHA256: container.decodeIfPresent(String.self, forKey: .certificateSHA256)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bridgeID, forKey: .bridgeID)
        try container.encode(host, forKey: .host)
        try container.encode(port, forKey: .port)
        try container.encodeIfPresent(modelID, forKey: .modelID)
        try container.encodeIfPresent(apiVersion, forKey: .apiVersion)
        try container.encodeIfPresent(certificateSHA256, forKey: .certificateSHA256)
    }
}

public struct RestoreJournal: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let bridgeID: String
    public let areaID: HueResourceID
    public let areaName: String
    public let createdAt: Date
    public var snapshots: [HueLightSnapshot]

    public init(
        id: UUID = UUID(),
        bridgeID: String,
        area: HueArea,
        lights: [HueLight],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.bridgeID = bridgeID
        areaID = area.id
        areaName = area.name
        self.createdAt = createdAt
        snapshots = lights.map { HueLightSnapshot(light: $0, capturedAt: createdAt) }
    }
}

public struct LiveSessionDescriptor: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let profile: BridgeProfile
    public let areaID: HueResourceID
    public let areaKind: HueAreaKind
    public let presetID: String
    public let brightness: Double
    public let duration: TimeInterval
    public let startedAt: Date

    public init(
        id: UUID = UUID(),
        profile: BridgeProfile,
        area: HueArea,
        presetID: String,
        brightness: Double,
        duration: TimeInterval,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.profile = profile
        areaID = area.id
        areaKind = area.kind
        self.presetID = presetID
        self.brightness = min(max(brightness, 5), 100)
        self.duration = min(max(duration, 60), 3_600)
        self.startedAt = startedAt
    }
}

public struct LiveSessionStatus: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable {
        case idle, starting, running, completed, cancelled, failed
    }

    public var sessionID: UUID?
    public var state: State
    public var progress: Double
    public var message: String
    public var updatedAt: Date

    public init(
        sessionID: UUID?,
        state: State,
        progress: Double,
        message: String,
        updatedAt: Date
    ) {
        self.sessionID = sessionID
        self.state = state
        self.progress = min(max(progress, 0), 1)
        self.message = message
        self.updatedAt = updatedAt
    }

    public static let idle = LiveSessionStatus(
        sessionID: nil,
        state: .idle,
        progress: 0,
        message: "No native Live session is running.",
        updatedAt: Date()
    )
}
