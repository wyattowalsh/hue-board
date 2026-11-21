import XCTest
import HueBoardKit
import HueBoardNativeCore
@testable import Hue_Board

@MainActor
final class RoomArrangementPersistenceTests: XCTestCase {
    private let room = StudioRehearsalRoom.sample.area
    private let bridge = "0000000000000001"

    private func makeModel(_ store: HueRoomLayoutStore) throws -> AppModel {
        let model = AppModel(roomLayoutStore: store)
        model.profile = try .init(bridgeID: bridge, host: "fixture.local")
        model.credential = .init(bridgeID: bridge, applicationKey: "synthetic")
        model.connectionState = .ready
        model.selectedAreaID = room.id
        model.areas = [room]
        model.loadCurrentRoomLayout()
        return model
    }

    private func arrangement() throws -> HueRoomArrangement {
        let config = try JSONDecoder().decode(HueEntertainmentConfigurationResource.self, from: Data(#"""
        {"id":"movie","locations":{"service_locations":[{"service":{"rid":"sample-0","rtype":"light"},"position":{"x":0.5,"y":0.25,"z":0}}]}}
        """#.utf8))
        return try XCTUnwrap(HueRoomDiscovery(configurations: [config], services: [], in: room).arrangements.first)
    }

    func testPartialImportPreviewCancelSaveReloadAndStaleRead() async throws {
        let suite = "hue-room-test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HueRoomLayoutStore(defaults: defaults)
        var seeded = HueRoomLayout.startingLayout(for: room)
        seeded.placements.removeLast()
        seeded.placements[0].selected = false
        seeded.placements[0].phase = 0.85
        seeded.placements[0].ceiling = 45
        seeded.placements[0].trim = 0.4
        seeded.placements[0].role = .task
        seeded.placements.append(.init(id: .init(rawValue: "temporarily-absent"), selected: false, x: 0.2, y: 0.3, phase: 0.4))
        try store.save(seeded, bridgeID: bridge, area: room)
        let model = try makeModel(store)
        let before = try XCTUnwrap(model.roomLayout)
        let imported = try arrangement()
        let preview = try model.previewRoomArrangement(imported, from: XCTUnwrap(model.roomDiscoveryScope))
        XCTAssertEqual(try store.load(bridgeID: bridge, area: room), before)
        model.loadCurrentRoomLayout()
        XCTAssertThrowsError(try model.saveRoomArrangement(preview))
        let fresh = try model.previewRoomArrangement(imported, from: XCTUnwrap(model.roomDiscoveryScope))
        model.hasRestorePoint = true
        XCTAssertFalse(model.canSaveRoomArrangement(fresh))
        model.hasRestorePoint = false
        try model.saveRoomArrangement(fresh)
        var expected = before
        expected.placements[0].x = 0.7
        expected.placements[0].y = 0.4
        XCTAssertEqual(try makeModel(store).roomLayout, expected)
        XCTAssertFalse(try XCTUnwrap(expected.placements.first { $0.id.rawValue == "sample-2" }).selected)
        let lease = await model.playbackCoordinator.currentLease()
        XCTAssertNil(lease)
    }

    func testSweepRequiresFreshEligibleMapAndOnlyCommitsApprovedPhases() async throws {
        let suite = "hue-sweep-test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HueRoomLayoutStore(defaults: defaults)
        var initial = StudioRehearsalRoom.sample.layout
        for index in initial.placements.indices { initial.placements[index].phase = 0.91 }
        try store.save(initial, bridgeID: bridge, area: room)
        let model = try makeModel(store)
        let candidate = try model.previewRoomSweep()
        XCTAssertEqual(try store.load(bridgeID: bridge, area: room), initial)
        model.updateRoomFixture(room.lights[1].id) { $0.selected = false }
        XCTAssertThrowsError(try model.saveRoomSweep(candidate))
        let fresh = try model.previewRoomSweep()
        try model.saveRoomSweep(fresh)
        let loadedModel = try makeModel(store)
        let rehearsal = try XCTUnwrap(loadedModel.studioRehearsalRoom)
        XCTAssertEqual(rehearsal.layout.placements.map(\.phase), [0, 0.91, 0.5])
        let frame = try await loadedModel.studioRehearsalFrame(loadedModel.studioRehearsalRequest(in: rehearsal, at: 0))
        XCTAssertEqual(Set(frame.targets.keys), [room.lights[0].id, room.lights[2].id])
        let rearranged = try loadedModel.previewRoomArrangement(arrangement(), from: XCTUnwrap(loadedModel.roomDiscoveryScope))
        try loadedModel.saveRoomArrangement(rearranged)
        XCTAssertEqual(loadedModel.roomLayout?.placements.map(\.phase), [0, 0.91, 0.5])
    }
}
