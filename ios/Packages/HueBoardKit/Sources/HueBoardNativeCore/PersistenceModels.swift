import Foundation
import HueBoardKit

public enum NativePersistenceVersion {
    public static let currentSchema = 2
    public static let defaultWriterVersion = "6.0.0-development"
}

public struct NativeAppState: Codable, Equatable, Sendable {
    public var profiles: [String: BridgeProfile]
    public var activeBridgeID: String?
    public var selectedAreaIDs: [String: String]
    public var sceneRegistry: [String: String]
    public var liveDescriptor: LiveSessionDescriptor?
    public var liveStatus: LiveSessionStatus

    public init(
        profiles: [String: BridgeProfile] = [:],
        activeBridgeID: String? = nil,
        selectedAreaIDs: [String: String] = [:],
        sceneRegistry: [String: String] = [:],
        liveDescriptor: LiveSessionDescriptor? = nil,
        liveStatus: LiveSessionStatus = .idle
    ) {
        self.profiles = profiles
        self.activeBridgeID = activeBridgeID
        self.selectedAreaIDs = selectedAreaIDs
        self.sceneRegistry = sceneRegistry
        self.liveDescriptor = liveDescriptor
        self.liveStatus = liveStatus
    }

    public var activeProfile: BridgeProfile? {
        guard let activeBridgeID else { return nil }
        return profiles[activeBridgeID]
    }
}

public struct PersistenceEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public let schemaVersion: Int
    public let writtenByVersion: String
    public let writtenAt: Date
    public let payloadSHA256: String
    public let payload: Payload

    public init(
        schemaVersion: Int,
        writtenByVersion: String,
        writtenAt: Date,
        payloadSHA256: String,
        payload: Payload
    ) {
        self.schemaVersion = schemaVersion
        self.writtenByVersion = writtenByVersion
        self.writtenAt = writtenAt
        self.payloadSHA256 = payloadSHA256
        self.payload = payload
    }
}

public struct PersistenceMigrationReport: Codable, Equatable, Sendable {
    public let sourceSchema: Int?
    public let targetSchema: Int
    public let startedAt: Date
    public let completedAt: Date
    public let migratedKeys: [String]
    public let quarantinedKeys: [String]
    public let legacyBackupCreated: Bool

    public init(
        sourceSchema: Int?,
        targetSchema: Int,
        startedAt: Date,
        completedAt: Date,
        migratedKeys: [String],
        quarantinedKeys: [String],
        legacyBackupCreated: Bool
    ) {
        self.sourceSchema = sourceSchema
        self.targetSchema = targetSchema
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.migratedKeys = migratedKeys
        self.quarantinedKeys = quarantinedKeys
        self.legacyBackupCreated = legacyBackupCreated
    }
}

public struct PersistenceQuarantineRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let key: String
    public let rawData: Data
    public let reason: String
    public let quarantinedAt: Date

    public init(
        id: UUID = UUID(),
        key: String,
        rawData: Data,
        reason: String,
        quarantinedAt: Date = Date()
    ) {
        self.id = id
        self.key = key
        self.rawData = rawData
        self.reason = reason
        self.quarantinedAt = quarantinedAt
    }
}

struct LegacyPersistenceBackup: Codable, Sendable {
    let capturedAt: Date
    let profile: Data?
    let selectedAreas: Data?
    let sceneRegistry: Data?
    let restoreJournal: Data?
    let liveDescriptor: Data?
    let liveStatus: Data?

    var containsData: Bool {
        profile != nil
            || selectedAreas != nil
            || sceneRegistry != nil
            || restoreJournal != nil
            || liveDescriptor != nil
            || liveStatus != nil
    }
}

public enum PersistenceError: Error, LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case checksumMismatch(String)
    case corruptRecord(String)
    case missingLegacyBackup
    case unknownBridge(String)
    case recoveryRequired(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let schema):
            return "This Hue Board state uses unsupported persistence schema \(schema)."
        case .checksumMismatch(let key):
            return "Saved Hue Board state failed its integrity check for \(key)."
        case .corruptRecord(let key):
            return "Saved Hue Board state could not be decoded for \(key)."
        case .missingLegacyBackup:
            return "No legacy Hue Board backup is available for rollback."
        case .unknownBridge(let bridgeID):
            return "No saved Hue Bridge profile exists for \(bridgeID)."
        case .recoveryRequired(let bridgeID):
            return "Restore or explicitly discard the saved baseline for Bridge \(bridgeID) first."
        }
    }
}
