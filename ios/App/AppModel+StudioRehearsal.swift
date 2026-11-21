import Foundation
import Observation
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
  /// A new input reading or playhead offset can reuse the last rendered map.
  /// Changing room, settings or capture ownership invalidates it immediately.
  func hasSameComposition(as other: Self) -> Bool {
    room == other.room && settings == other.settings && safety == other.safety &&
      cues == other.cues && duration == other.duration && (signal == nil) == (other.signal == nil)
  }

}

@MainActor
extension AppModel {
  var studioRehearsalRoom: StudioRehearsalRoom? {
    guard let area = selectedArea else { return isReady ? nil : .sample }
    guard roomLayoutIssue == nil, let layout = roomLayout, layout.areaID == area.id else { return nil }
    if let profile, roomLayoutScope != "\(profile.bridgeID)/\(area.id.rawValue)" { return nil }
    return .init(area: area, layout: layout)
  }

  func studioRehearsalRequest(in room: StudioRehearsalRoom, at elapsed: TimeInterval) -> StudioRehearsalRequest {
    let safety = effectiveSafetySettings
    var settings = studioSettings
    settings.brightness = PhysicalLightSafetyPolicy.clampedBrightness(brightness, settings: safety)
    let cues = isCueSequenceEnabled ? HueCueSequence(
      presetIDs: cueIDs, holdSeconds: cueHoldSeconds,
      order: cueOrder, seed: settings.seed
    ) : nil
    return .init(
      room: room, settings: settings, safety: safety, cues: cues,
      elapsed: min(elapsed, liveDuration), duration: liveDuration,
      signal: safety.reduceLightMotion ? nil : studioInputPreview.signal
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

/// Keep one engine evaluation in flight and one latest request waiting behind it.
/// A fast input meter must not erase the map or starve larger rooms of completed frames.
@MainActor
@Observable
final class StudioRehearsalPresentation {
  private(set) var frame: StudioPlannedFrame?
  private(set) var issue: String?
  private(set) var renderedRequest: StudioRehearsalRequest?

  @ObservationIgnored private var latest: StudioRehearsalRequest?
  @ObservationIgnored private var worker: Task<Void, Never>?
  @ObservationIgnored private var generation = 0

  func update(
    _ next: StudioRehearsalRequest?,
    evaluate: @escaping @MainActor (StudioRehearsalRequest) async throws -> StudioPlannedFrame
  ) {
    guard let next else { clear(); return }
    if let latest, !latest.hasSameComposition(as: next) { clear() }
    latest = next
    guard worker == nil else { return }
    let myGeneration = generation
    worker = Task { [weak self] in
      while !Task.isCancelled, let pending = self?.latest {
        // A new meter reading may arrive while awaiting this frame. Finish one
        // sample for this timeline offset before moving to the newest reading.
        do {
          let result = try await evaluate(pending)
          guard let self, self.generation == myGeneration, !Task.isCancelled else { return }
          if self.latest?.elapsed == pending.elapsed {
            self.frame = result
            self.issue = nil
            self.renderedRequest = pending
          }
        } catch {
          guard let self, self.generation == myGeneration, !Task.isCancelled else { return }
          if self.latest == pending {
            self.frame = nil
            self.issue = error.localizedDescription
            self.renderedRequest = pending
          }
        }
        guard let self, self.generation == myGeneration else { return }
        if self.latest == pending {
          self.worker = nil
          return
        }
      }
    }
  }

  func clear() {
    generation &+= 1
    worker?.cancel()
    worker = nil
    latest = nil
    renderedRequest = nil
    frame = nil
    issue = nil
  }
}
