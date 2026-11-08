import Foundation

public enum HuePlaybackMode: String, Codable, Sendable {
    case idle
    case bridge
    case liveForeground
    case liveContinued
    case stopping
    case failed
}

public enum HuePlaybackPhase: String, Codable, Sendable {
    case ready
    case preparing
    case requestPending
    case accepted
    case reported
    case uncertain
    case running
    case finishing
    case stopped
    case failed
}

public struct HuePlaybackSnapshot: Codable, Equatable, Sendable {
    public var mode: HuePlaybackMode
    public var phase: HuePlaybackPhase
    public var presetID: String?
    public var sceneID: HueResourceID?
    public var sessionID: UUID?
    public var startedAt: Date?
    public var duration: TimeInterval?
    public var progress: Double
    public var message: String

    public init(
        mode: HuePlaybackMode = .idle,
        phase: HuePlaybackPhase = .ready,
        presetID: String? = nil,
        sceneID: HueResourceID? = nil,
        sessionID: UUID? = nil,
        startedAt: Date? = nil,
        duration: TimeInterval? = nil,
        progress: Double = 0,
        message: String = "Ready. Opening Hue Board does not change lights."
    ) {
        self.mode = mode
        self.phase = phase
        self.presetID = presetID
        self.sceneID = sceneID
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.duration = duration
        self.progress = min(max(progress, 0), 1)
        self.message = message
    }
}

public struct HuePlaybackMachine: Sendable {
    public private(set) var snapshot: HuePlaybackSnapshot

    public init(snapshot: HuePlaybackSnapshot = .init()) {
        self.snapshot = snapshot
    }

    public mutating func beginBridge(presetID: String) {
        snapshot = .init(
            mode: .bridge,
            phase: .preparing,
            presetID: presetID,
            message: "Preparing a Bridge-native scene."
        )
    }

    public mutating func markBridgeRequestPending(sceneID: HueResourceID) {
        snapshot.sceneID = sceneID
        snapshot.phase = .requestPending
        snapshot.message = "Waiting for the Bridge to acknowledge dynamic playback."
    }

    public mutating func markBridgeAccepted(sceneID: HueResourceID, at date: Date = Date()) {
        snapshot.sceneID = sceneID
        snapshot.phase = .accepted
        snapshot.startedAt = date
        snapshot.message = "Bridge playback accepted. The Bridge continues independently when the app leaves."
    }

    public mutating func markBridgeReported() {
        snapshot.phase = .reported
        snapshot.message = "Bridge readback reports dynamic playback. This is not optical measurement."
    }

    public mutating func markUncertain(_ message: String) {
        snapshot.phase = .uncertain
        snapshot.message = message
    }

    public mutating func beginLive(
        presetID: String,
        duration: TimeInterval,
        continued: Bool,
        at date: Date = Date()
    ) -> UUID {
        let id = UUID()
        snapshot = .init(
            mode: continued ? .liveContinued : .liveForeground,
            phase: .running,
            presetID: presetID,
            sessionID: id,
            startedAt: date,
            duration: duration,
            message: continued
                ? "Live session started with iOS continued-processing support."
                : "Live session is foreground-only on this device."
        )
        return id
    }

    public mutating func updateLiveProgress(_ progress: Double) {
        guard snapshot.mode == .liveForeground || snapshot.mode == .liveContinued else { return }
        snapshot.progress = min(max(progress, 0), 1)
    }

    public mutating func finishLive() {
        snapshot.phase = .stopped
        snapshot.progress = 1
        snapshot.message = "Live session completed. The current static light state remains."
    }

    public mutating func beginStopping() {
        snapshot.mode = .stopping
        snapshot.phase = .finishing
        snapshot.message = "Stopping playback and restoring captured light state."
    }

    public mutating func stop(_ message: String = "Playback stopped.") {
        snapshot = .init(phase: .stopped, message: message)
    }

    public mutating func fail(_ message: String) {
        snapshot.mode = .failed
        snapshot.phase = .failed
        snapshot.message = message
    }
}
