import Foundation
import HueBoardKit

struct NativeLiveProgress: Equatable, Sendable {
  let fraction: Double
  let elapsed: TimeInterval
  let remaining: TimeInterval
  let writes: Int
}

actor NativeLiveRunner {
  private let engine: any HueEngineSampling
  private var running = false

  init(engine: any HueEngineSampling) {
    self.engine = engine
  }

  func run(
    area: HueArea,
    preset: HuePreset,
    brightness: Double,
    duration: TimeInterval,
    submit: @escaping @Sendable (LightingFrame) async throws -> Void,
    progress: @escaping @Sendable (NativeLiveProgress) async -> Void
  ) async throws {
    guard !running else {
      throw HueBoardError.unsupported("An Ambient Live session is already running.")
    }
    let lights = area.lights.filter {
      $0.capabilities.color && $0.capabilities.dimming && !$0.capabilities.streaming
    }
    guard !lights.isEmpty else {
      throw HueBoardError.unsupported(
        "No non-streaming color lights are available for Ambient Live."
      )
    }
    guard duration > 0 else {
      throw HueBoardError.unsupported("Choose a positive Live duration.")
    }
    running = true
    defer { running = false }

    let settings = HueEngineSettings.from(preset: preset, brightness: brightness)
    let clock = ContinuousClock()
    let started = clock.now
    let transition = max(4_500, lights.count * 550)
    let minimumCycleSeconds = Double(transition) / 1_000
    var writes = 0
    var sequence: UInt64 = 0

    while true {
      try Task.checkCancellation()
      let cycleStarted = clock.now
      let elapsed = started.duration(to: cycleStarted).seconds
      if elapsed >= duration { break }

      var actions: [HueResourceID: HueLightAction] = [:]
      for (index, light) in lights.enumerated() {
        let position = Double(index) / Double(max(1, lights.count))
        let sampled = try await engine.sample(
          time: elapsed,
          position: position,
          settings: settings,
          surge: 0
        )
        let xy = try await engine.xy(sampled.color, gamut: light.gamut)
        actions[light.id] = HueLightAction(
          on: .init(on: true),
          dimming: .init(brightness: min(sampled.brightness, light.outputLimit)),
          color: .init(xy: xy),
          dynamics: .init(duration: transition)
        )
      }
      sequence &+= 1
      try await submit(
        LightingFrame(sequence: sequence, generatedAt: Date(), actions: actions)
      )
      writes += actions.count
      let current = started.duration(to: clock.now).seconds
      await progress(
        .init(
          fraction: min(1, current / duration),
          elapsed: current,
          remaining: max(0, duration - current),
          writes: writes
        )
      )

      let cycleElapsed = cycleStarted.duration(to: clock.now).seconds
      let waitSeconds = minimumCycleSeconds - cycleElapsed
      if waitSeconds > 0 {
        try await Task.sleep(
          for: .milliseconds(Int64((waitSeconds * 1_000).rounded(.up)))
        )
      }
    }
    await progress(.init(fraction: 1, elapsed: duration, remaining: 0, writes: writes))
  }
}

extension Duration {
  fileprivate var seconds: Double {
    let components = self.components
    return Double(components.seconds) + Double(components.attoseconds) / 1e18
  }
}
