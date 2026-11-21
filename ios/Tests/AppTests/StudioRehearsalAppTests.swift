import XCTest
import HueBoardKit
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
}
