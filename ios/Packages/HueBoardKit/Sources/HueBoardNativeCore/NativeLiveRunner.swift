import Foundation
import HueBoardKit

/// Input normalized for one existing Ambient Live REST transition.
public struct HueLiveSignal: Equatable, Sendable {
  public let level: Double
  public let color: RGB?

  public init(level: Double, color: RGB? = nil) {
    self.level = level.isFinite ? Self.unitValue(level) : 0
    if let color, color.components.allSatisfy(\.isFinite) {
      self.color = RGB(
        red: Self.unitValue(color.red),
        green: Self.unitValue(color.green),
        blue: Self.unitValue(color.blue)
      )
    } else {
      self.color = nil
    }
  }

  func applying(to frame: HueLightFrame, brightnessLimit: Double) -> HueLightFrame {
    let lift = min(8, max(0, frame.brightness) * 0.12) * level
    let brightness = min(frame.brightness + lift, brightnessLimit)
    guard let color else { return .init(color: frame.color, brightness: brightness) }

    let tintAmount = 0.18
    return .init(
      color: RGB(
        red: frame.color.red + (color.red - frame.color.red) * tintAmount,
        green: frame.color.green + (color.green - frame.color.green) * tintAmount,
        blue: frame.color.blue + (color.blue - frame.color.blue) * tintAmount
      ),
      brightness: brightness
    )
  }

  private static func unitValue(_ value: Double) -> Double { min(max(value, 0), 1) }
}

public struct NativeLiveProgress: Equatable, Sendable {
  public let fraction: Double
  public let elapsed: TimeInterval
  public let remaining: TimeInterval
  public let writes: Int
  public let cue: HueCueAtTime?
}

public actor NativeLiveRunner {
  private let engine: any HueEngineSampling
  private var running = false

  public init(engine: any HueEngineSampling) {
    self.engine = engine
  }

  public func run(
    area: HueArea,
    layout: HueRoomLayout,
    settings requestedSettings: HueEngineSettings,
    cueSequence: HueCueSequence?,
    contract: HueBoardContract,
    duration: TimeInterval,
    safetySettings: PhysicalLightSafetySettings,
    signal: (@Sendable (TimeInterval) async throws -> HueLiveSignal)? = nil,
    submit: @escaping @Sendable (LightingFrame) async throws -> Void,
    progress: @escaping @Sendable (NativeLiveProgress) async -> Void
  ) async throws {
    guard !running else {
      throw HueBoardError.unsupported("An Ambient Live session is already running.")
    }
    let planner = try StudioFramePlanner(
      area: area, layout: layout, settings: requestedSettings, cueSequence: cueSequence,
      contract: contract, safety: safetySettings
    )
    guard planner.fixtureCount > 0 else {
      throw HueBoardError.unsupported(
        "No non-streaming color lights are available within the current brightness limit."
      )
    }
    guard duration.isFinite, duration > 0 else {
      throw HueBoardError.unsupported("Choose a positive Live duration.")
    }
    running = true
    defer { running = false }

    let clock = ContinuousClock()
    let started = clock.now
    let transition = planner.transitionMilliseconds
    let minimumCycleSeconds = Double(transition) / 1_000
    let sampleSignal = planner.acceptsSignal ? signal : nil
    var writes = 0
    var sequence: UInt64 = 0

    while true {
      try Task.checkCancellation()
      let cycleStarted = clock.now
      let elapsed = started.duration(to: cycleStarted).seconds
      if elapsed >= duration { break }

      let transitionSignal = try await sampleSignal?(elapsed)
      try Task.checkCancellation()
      if started.duration(to: clock.now).seconds >= duration { break }

      let frame = try await planner.frame(
        at: elapsed, duration: duration, signal: transitionSignal, engine: engine
      )
      let actions = frame.targets.mapValues { target in
        HueLightAction(
          on: .init(on: true), dimming: .init(brightness: target.brightness),
          color: .init(xy: target.xy), dynamics: .init(duration: transition)
        )
      }
      try Task.checkCancellation()
      if started.duration(to: clock.now).seconds >= duration { break }
      if !actions.isEmpty {
        sequence &+= 1
        try await submit(
          LightingFrame(sequence: sequence, generatedAt: Date(), actions: actions)
        )
        writes += actions.count
      }
      let current = started.duration(to: clock.now).seconds
      await progress(
        .init(
          fraction: min(1, current / duration),
          elapsed: current,
          remaining: max(0, duration - current),
          writes: writes,
          cue: frame.cue
        )
      )

      let now = clock.now
      let cycleElapsed = cycleStarted.duration(to: now).seconds
      let remaining = duration - started.duration(to: now).seconds
      let waitSeconds = min(minimumCycleSeconds - cycleElapsed, remaining)
      if waitSeconds > 0 {
        try await Task.sleep(
          for: .milliseconds(Int64((waitSeconds * 1_000).rounded(.up)))
        )
      }
    }
    await progress(.init(
      fraction: 1,
      elapsed: duration,
      remaining: 0,
      writes: writes,
      cue: nil
    ))
  }
}

extension Duration {
  fileprivate var seconds: Double {
    let components = self.components
    return Double(components.seconds) + Double(components.attoseconds) / 1e18
  }
}
