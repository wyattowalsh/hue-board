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

  fileprivate func applying(to frame: HueLightFrame, brightnessLimit: Double) -> HueLightFrame {
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
    try layout.validate(for: area)
    let brightnessLimit = safetySettings.maximumDynamicBrightness
    let selected = layout.selectedEntries(in: area).filter { $0.0.minimumBrightness <= brightnessLimit }
    guard !selected.isEmpty else {
      throw HueBoardError.unsupported(
        "No non-streaming color lights are available within the current brightness limit."
      )
    }
    guard duration.isFinite, duration > 0 else {
      throw HueBoardError.unsupported("Choose a positive Live duration.")
    }
    running = true
    defer { running = false }

    if let cueSequence {
      try cueSequence.validate(contract: contract)
    }
    let clock = ContinuousClock()
    let started = clock.now
    let transition = PhysicalLightSafetyPolicy.restTransitionMilliseconds(
      lightCount: selected.count,
      settings: safetySettings
    )
    let minimumCycleSeconds = Double(transition) / 1_000
    let sampleSignal = !safetySettings.reduceLightMotion
      && selected.contains { !$0.1.role.isStatic } ? signal : nil
    var writes = 0
    var sequence: UInt64 = 0

    while true {
      try Task.checkCancellation()
      let cycleStarted = clock.now
      let elapsed = started.duration(to: cycleStarted).seconds
      if elapsed >= duration { break }

      let selectedCue = try cueSequence?.settings(
        at: elapsed,
        contract: contract,
        base: requestedSettings
      )
      let settings = PhysicalLightSafetyPolicy.adjustedEngineSettings(
        selectedCue?.settings ?? requestedSettings,
        safety: safetySettings
      )
      let cueTime = selectedCue?.cue.slotElapsed ?? elapsed
      let transitionSignal = try await sampleSignal?(elapsed)
      try Task.checkCancellation()
      if started.duration(to: clock.now).seconds >= duration { break }

      var actions: [HueResourceID: HueLightAction] = [:]
      for (light, placement) in selected {
        let sampleTime = placement.role.isStatic ? 0 : cueTime
        let patternSpeed = settings.speed.isFinite ? max(settings.speed, 0) : 0
        let position = placement.role == .accent
          ? (placement.phase + 0.25).truncatingRemainder(dividingBy: 1)
          : placement.phase
        let sampled = try await engine.sample(
          time: sampleTime * patternSpeed,
          position: position,
          settings: settings,
          surge: 0
        )
        let adapted = placement.role.isStatic
          ? sampled
          : transitionSignal?.applying(to: sampled, brightnessLimit: settings.brightness) ?? sampled
        guard let brightness = placement.brightness(
          for: adapted.brightness, light: light
        ) else { continue }
        let xy = try await engine.xy(adapted.color, gamut: light.gamut)
        actions[light.id] = HueLightAction(
          on: .init(on: true),
          dimming: .init(brightness: min(brightness, brightnessLimit)),
          color: .init(xy: xy),
          dynamics: .init(duration: transition)
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
          cue: selectedCue?.cue
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
