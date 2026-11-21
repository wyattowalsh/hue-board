import Foundation
import HueBoardKit
import HueBoardNativeCore

struct StudioRehearsalRoom: Equatable {
  let area: HueArea
  let layout: HueRoomLayout

  static let sample: Self = {
    let lights = ["Left", "Center", "Right"].enumerated().map { index, name in
      HueLight(
        id: .init(rawValue: "sample-\(index)"), ownerID: nil, name: name,
        isOn: true, brightness: 50, color: nil, colorTemperatureMirek: nil, gamut: nil,
        capabilities: .init(power: true, dimming: true, color: true,
                            colorTemperature: false, dynamicPalette: true)
      )
    }
    let area = HueArea(id: .init(rawValue: "offline-sample"), kind: .room, name: "Sample room", lights: lights)
    var layout = HueRoomLayout.startingLayout(for: area)
    for i in lights.indices {
      layout.placements[i].x = 0.18 + 0.32 * Double(i)
      layout.placements[i].y = 0.5
    }
    return .init(area: area, layout: layout)
  }()
}

struct StudioRehearsalRequest: Equatable {
  let room: StudioRehearsalRoom
  let settings: HueEngineSettings
  let safety: PhysicalLightSafetySettings
  let cues: HueCueSequence?
  let elapsed: TimeInterval
  let duration: TimeInterval
  let signal: HueLiveSignal?
}

@MainActor
extension AppModel {
  var studioRehearsalRoom: StudioRehearsalRoom? {
    guard let area = selectedArea else { return isReady ? nil : .sample }
    guard roomLayoutIssue == nil, let layout = roomLayout, layout.areaID == area.id else { return nil }
    return .init(area: area, layout: layout)
  }

  func studioRehearsalRequest(in room: StudioRehearsalRoom, at elapsed: TimeInterval) -> StudioRehearsalRequest {
    var settings = studioSettings
    settings.brightness = effectiveDynamicBrightness
    let cues = isCueSequenceEnabled ? HueCueSequence(
      presetIDs: cueIDs, holdSeconds: cueHoldSeconds,
      order: cueOrder, seed: settings.seed
    ) : nil
    return .init(
      room: room, settings: settings, safety: safetySettings, cues: cues,
      elapsed: min(elapsed, liveDuration), duration: liveDuration,
      signal: studioInputPreview.signal
    )
  }

  func studioRehearsalFrame(_ request: StudioRehearsalRequest) async throws -> StudioPlannedFrame {
    let planner = try StudioFramePlanner(
      area: request.room.area, layout: request.room.layout, settings: request.settings,
      cueSequence: request.cues, contract: contract, safety: request.safety
    )
    return try await planner.frame(
      at: request.elapsed, duration: request.duration, signal: request.signal, engine: engine
    )
  }
}
