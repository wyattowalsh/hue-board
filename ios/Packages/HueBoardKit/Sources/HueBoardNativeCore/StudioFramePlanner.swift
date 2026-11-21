import Foundation
import HueBoardKit

public struct StudioFixtureTarget: Equatable, Sendable {
  public let color: RGB
  public let brightness: Double
  public let xy: HueXY
}

public struct StudioPlannedFrame: Equatable, Sendable {
  public let targets: [HueResourceID: StudioFixtureTarget]
  public let cue: HueCueAtTime?
  public let ended: Bool
}

/// A captured composition. Evaluating an elapsed time only reads the injected engine.
public struct StudioFramePlanner: Sendable {
  private let selected: [(HueLight, HueFixturePlacement)]
  private let requestedSettings: HueEngineSettings
  private let cueSequence: HueCueSequence?
  private let contract: HueBoardContract
  private let safety: PhysicalLightSafetySettings
  public let transitionMilliseconds: Int
  public let acceptsSignal: Bool
  public var fixtureCount: Int { selected.count }

  public init(
    area: HueArea, layout: HueRoomLayout, settings: HueEngineSettings,
    cueSequence: HueCueSequence?, contract: HueBoardContract, safety: PhysicalLightSafetySettings
  ) throws {
    try layout.validate(for: area)
    try cueSequence?.validate(contract: contract)
    guard settings.brightness.isFinite else {
      throw HueBoardError.invalidResponse("The Studio brightness is invalid.")
    }
    let master = PhysicalLightSafetyPolicy.clampedBrightness(settings.brightness, settings: safety)
    let selected = layout.selectedEntries(in: area, brightnessLimit: master)
    self.selected = selected
    self.requestedSettings = settings
    self.cueSequence = cueSequence
    self.contract = contract
    self.safety = safety
    self.transitionMilliseconds = PhysicalLightSafetyPolicy.restTransitionMilliseconds(
      lightCount: selected.count, settings: safety
    )
    self.acceptsSignal = !safety.reduceLightMotion && selected.contains { !$0.1.role.isStatic }
  }

  public func frame(
    at elapsed: TimeInterval, duration: TimeInterval, signal: HueLiveSignal?,
    engine: any HueEngineSampling
  ) async throws -> StudioPlannedFrame {
    try Task.checkCancellation()
    guard elapsed.isFinite, elapsed >= 0, duration.isFinite, duration > 0 else {
      throw HueBoardError.unsupported("The rehearsal time or session duration is invalid.")
    }
    if elapsed >= duration { return .init(targets: [:], cue: nil, ended: true) }
    let selectedCue = try cueSequence?.settings(at: elapsed, contract: contract, base: requestedSettings)
    let settings = PhysicalLightSafetyPolicy.adjustedEngineSettings(
      selectedCue?.settings ?? requestedSettings, safety: safety
    )
    let cueTime = selectedCue?.cue.slotElapsed ?? elapsed
    let patternSpeed = settings.speed.isFinite ? max(settings.speed, 0) : 0
    var targets: [HueResourceID: StudioFixtureTarget] = [:]
    for (light, placement) in selected {
      try Task.checkCancellation()
      let sampleTime = placement.role.isStatic ? 0 : cueTime
      let position = placement.role == .accent
        ? (placement.phase + 0.25).truncatingRemainder(dividingBy: 1) : placement.phase
      let sampled = try await engine.sample(
        time: sampleTime * patternSpeed, position: position, settings: settings, surge: 0
      )
      let adapted: HueLightFrame
      if acceptsSignal, !placement.role.isStatic, let signal {
        adapted = signal.applying(to: sampled, brightnessLimit: settings.brightness)
      } else {
        adapted = sampled
      }
      guard let brightness = placement.brightness(for: adapted.brightness, light: light) else { continue }
      let xy = try await engine.xy(adapted.color, gamut: light.gamut)
      targets[light.id] = .init(color: adapted.color, brightness: min(brightness, settings.brightness), xy: xy)
    }
    try Task.checkCancellation()
    return .init(targets: targets, cue: selectedCue?.cue, ended: false)
  }
}
