import Foundation

public enum HuePlaybackMode: Equatable, Sendable {
  case idle
  case connecting
  case bridgePending(presetID: String)
  case bridgeAccepted(sceneID: String, presetID: String)
  case bridgeUncertain(sceneID: String?, presetID: String, reason: String)
  case live(presetID: String, startedAt: Date, endsAt: Date)
  case stopping
  case failed(String)
}

public struct HuePlaybackStateMachine: Equatable, Sendable {
  public private(set) var mode: HuePlaybackMode = .idle

  public init() {}

  public mutating func beginBridgePlay(presetID: String) throws {
    guard canStart else { throw HuePlaybackTransitionError.busy }
    mode = .bridgePending(presetID: presetID)
  }

  public mutating func acceptBridgePlay(sceneID: String, presetID: String) throws {
    guard case .bridgePending(let pending) = mode, pending == presetID else {
      throw HuePlaybackTransitionError.invalidTransition
    }
    mode = .bridgeAccepted(sceneID: sceneID, presetID: presetID)
  }

  public mutating func markBridgeUncertain(sceneID: String?, presetID: String, reason: String) {
    mode = .bridgeUncertain(sceneID: sceneID, presetID: presetID, reason: reason)
  }

  public mutating func beginLive(presetID: String, duration: TimeInterval, now: Date = .now) throws
  {
    guard canStart else { throw HuePlaybackTransitionError.busy }
    guard duration > 0 else { throw HuePlaybackTransitionError.invalidDuration }
    mode = .live(presetID: presetID, startedAt: now, endsAt: now.addingTimeInterval(duration))
  }

  public mutating func finishLive() throws {
    guard case .live = mode else { throw HuePlaybackTransitionError.invalidTransition }
    mode = .idle
  }

  public mutating func beginStopping() {
    mode = .stopping
  }

  public mutating func finishStop() {
    mode = .idle
  }

  public mutating func fail(_ message: String) {
    mode = .failed(message)
  }

  public var canStart: Bool {
    switch mode {
    case .idle, .failed: true
    default: false
    }
  }
}

public enum HuePlaybackTransitionError: Error, LocalizedError {
  case busy
  case invalidTransition
  case invalidDuration

  public var errorDescription: String? {
    switch self {
    case .busy: return "Another playback operation is active."
    case .invalidTransition: return "The playback response does not match the pending request."
    case .invalidDuration: return "Live sessions require a positive duration."
    }
  }
}
