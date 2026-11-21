import XCTest
import HueBoardKit
import HueBoardNativeCore
@testable import Hue_Board

final class StudioRehearsalAppTests: XCTestCase {
  @MainActor
  func testOfflineRoomAndScrubbingDoNotStartCaptureOrLighting() async throws {
    let suite = "StudioRehearsalTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(setupDefaults: defaults)
    let room = try XCTUnwrap(model.studioRehearsalRoom)
    XCTAssertEqual(room.area.name, "Sample room")
    let baseline = model.playbackSnapshot
    let before = defaults.persistentDomain(forName: suite) as NSDictionary?
    model.isCueSequenceEnabled = true
    model.cueHoldSeconds = 30
    let request = model.studioRehearsalRequest(in: room, at: 30)
    let frame = try await model.studioRehearsalFrame(request)
    XCTAssertEqual(frame.targets.count, 3)
    XCTAssertEqual(frame.cue?.position, 1)
    XCTAssertEqual(model.playbackSnapshot, baseline)
    XCTAssertFalse(model.hasRestorePoint)
    XCTAssertNil(model.roomLayout)
    XCTAssertFalse(model.studioMicrophone.isCapturing)
    XCTAssertNil(model.studioMedia.player)
    let lease = await model.playbackCoordinator.currentLease()
    XCTAssertNil(lease)
    XCTAssertEqual(before, defaults.persistentDomain(forName: suite) as NSDictionary?)
  }

  @MainActor
  func testKnownEmptyOrChangedRoomCannotUseSampleFixtures() async throws {
    let suite = "StudioRehearsalTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(setupDefaults: defaults)
    let area = HueArea(id: .init(rawValue: "empty"), kind: .room, name: "Empty", lights: [])
    model.areas = [area]
    model.selectedAreaID = area.id
    model.roomLayout = StudioRehearsalRoom.sample.layout
    XCTAssertNil(model.studioRehearsalRoom)
    model.roomLayout = .startingLayout(for: area)
    let room = try XCTUnwrap(model.studioRehearsalRoom)
    let frame = try await model.studioRehearsalFrame(model.studioRehearsalRequest(in: room, at: 0))
    XCTAssertEqual(room.area.id, area.id)
    XCTAssertTrue(frame.targets.isEmpty)
  }

  @MainActor
  func testContinuousInputFinishesAnInFlightFrameAndCoalescesIntermediateReadings() async throws {
    let suite = "StudioRehearsalTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(setupDefaults: defaults)
    let base = model.studioRehearsalRequest(in: .sample, at: 0)
    let frame = try await model.studioRehearsalFrame(base)
    func reading(_ level: Double) -> StudioRehearsalRequest {
      .init(room: base.room, settings: base.settings, safety: base.safety, cues: base.cues,
            elapsed: 0, duration: base.duration, signal: .init(level: level))
    }
    let output = StudioRehearsalPresentation()
    var levels: [Double] = []
    var resume: CheckedContinuation<Void, Never>?
    let evaluate: @MainActor (StudioRehearsalRequest) async throws -> StudioPlannedFrame = { request in
      levels.append(try XCTUnwrap(request.signal?.level))
      await withCheckedContinuation { resume = $0 }
      return frame
    }
    output.update(reading(0.1), evaluate: evaluate)
    await waitUntil { resume != nil }
    output.update(reading(0.2), evaluate: evaluate)
    output.update(reading(0.3), evaluate: evaluate)
    resume?.resume()
    resume = nil
    await waitUntil { resume != nil && output.renderedRequest?.signal?.level == 0.1 }
    XCTAssertEqual(levels, [0.1, 0.3])
    XCTAssertEqual(output.frame, frame)
    resume?.resume()
    resume = nil
    await waitUntil { output.renderedRequest?.signal?.level == 0.3 }
    output.update(reading(0.4), evaluate: evaluate)
    await waitUntil { resume != nil }
    output.clear()
    resume?.resume()
    output.update(base) { _ in frame }
    await waitUntil { output.renderedRequest == base }
    XCTAssertNil(output.renderedRequest?.signal)
  }

  @MainActor
  private func waitUntil(
    _ condition: @MainActor () -> Bool,
    file: StaticString = #filePath, line: UInt = #line
  ) async {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !condition() && ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(1))
    }
    XCTAssertTrue(condition(), file: file, line: line)
  }

}
