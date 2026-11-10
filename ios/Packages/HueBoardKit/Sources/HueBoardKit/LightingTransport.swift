import Foundation

public struct LightingScope: Codable, Equatable, Hashable, Sendable {
    public let bridgeID: String
    public let areaID: HueResourceID

    public init(bridgeID: String, areaID: HueResourceID) {
        self.bridgeID = bridgeID
        self.areaID = areaID
    }
}

public enum LightingTransportKind: String, Codable, CaseIterable, Sendable {
    case preview
    case bridgeScene
    case restAmbient
    case entertainment
}

public struct LightingTransportCapabilities: Codable, Equatable, Sendable {
    public let performsPhysicalWrites: Bool
    public let continuesWithoutAppExecution: Bool
    public let supportsFrameSubmission: Bool
    public let supportsHighRateFrames: Bool

    public init(
        performsPhysicalWrites: Bool,
        continuesWithoutAppExecution: Bool,
        supportsFrameSubmission: Bool,
        supportsHighRateFrames: Bool
    ) {
        self.performsPhysicalWrites = performsPhysicalWrites
        self.continuesWithoutAppExecution = continuesWithoutAppExecution
        self.supportsFrameSubmission = supportsFrameSubmission
        self.supportsHighRateFrames = supportsHighRateFrames
    }
}

public struct LightingPlaybackRequest: Codable, Equatable, Sendable {
    public let scope: LightingScope
    public let transport: LightingTransportKind
    public let presetID: String
    public let duration: TimeInterval?

    public init(
        scope: LightingScope,
        transport: LightingTransportKind,
        presetID: String,
        duration: TimeInterval? = nil
    ) {
        self.scope = scope
        self.transport = transport
        self.presetID = presetID
        self.duration = duration
    }
}

public struct LightingFrame: Codable, Equatable, Sendable {
    public let sequence: UInt64
    public let generatedAt: Date
    public let actions: [HueResourceID: HueLightAction]

    public init(
        sequence: UInt64,
        generatedAt: Date = Date(),
        actions: [HueResourceID: HueLightAction]
    ) {
        self.sequence = sequence
        self.generatedAt = generatedAt
        self.actions = actions
    }
}

public struct PlaybackOperationID: Codable, Equatable, Hashable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct WriterEpoch: Codable, Equatable, Hashable, Comparable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static func < (lhs: WriterEpoch, rhs: WriterEpoch) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct PlaybackWriterLease: Codable, Equatable, Hashable, Sendable {
    public let operationID: PlaybackOperationID
    public let epoch: WriterEpoch
    public let scope: LightingScope
    public let transport: LightingTransportKind
    public let startedAt: Date

    public init(
        operationID: PlaybackOperationID,
        epoch: WriterEpoch,
        scope: LightingScope,
        transport: LightingTransportKind,
        startedAt: Date
    ) {
        self.operationID = operationID
        self.epoch = epoch
        self.scope = scope
        self.transport = transport
        self.startedAt = startedAt
    }
}

public enum PlaybackStopReason: String, Codable, Sendable {
    case completed
    case user
    case replaced
    case cancelled
    case expired
    case failed
    case recovery
    case appTermination
}

public enum PlaybackCoordinationError: Error, LocalizedError, Equatable, Sendable {
    case busy(PlaybackWriterLease)
    case staleLease(PlaybackWriterLease)
    case transportMismatch(expected: LightingTransportKind, actual: LightingTransportKind)
    case frameSubmissionUnsupported(LightingTransportKind)

    public var errorDescription: String? {
        switch self {
        case .busy(let lease):
            return "Playback operation \(lease.operationID.rawValue) already owns this writer."
        case .staleLease(let lease):
            return "Playback operation \(lease.operationID.rawValue) no longer owns the writer."
        case .transportMismatch(let expected, let actual):
            return "Playback requires \(expected.rawValue), not \(actual.rawValue)."
        case .frameSubmissionUnsupported(let kind):
            return "The \(kind.rawValue) transport does not accept lighting frames."
        }
    }
}

public protocol LightingTransport: Sendable {
    var kind: LightingTransportKind { get }
    var capabilities: LightingTransportCapabilities { get }

    func prepare(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws

    func start(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws

    func submit(
        _ frame: LightingFrame,
        lease: PlaybackWriterLease
    ) async throws

    func stop(
        lease: PlaybackWriterLease,
        reason: PlaybackStopReason
    ) async
}
