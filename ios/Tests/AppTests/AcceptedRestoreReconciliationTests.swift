import Foundation
import HueBoardKit
import HueBoardNativeCore
import XCTest
@testable import Hue_Board

@MainActor
final class AcceptedRestoreReconciliationTests: XCTestCase {
    private let bridge = "0000000000000001"
    private let otherBridge = "0000000000000002"
    private let baselineDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func light(_ id: String, x: Double = 0.3, mirek: Int? = nil) -> HueLight {
        .init(id: .init(rawValue: id), ownerID: nil, name: "Test lamp", isOn: true,
              brightness: 50, color: .init(x: x, y: 0.31), colorTemperatureMirek: mirek,
              gamut: nil, capabilities: .init(power: true, dimming: true, color: true,
                                               colorTemperature: true, dynamicPalette: false),
              temperatureMinimumMirek: 153, temperatureMaximumMirek: 500)
    }

    private func room(_ lights: [HueLight]) -> HueArea {
        .init(id: .init(rawValue: "room"), kind: .room, name: "Test room", lights: lights)
    }

    private func expectStored(
        _ expected: RestoreJournal?, in suite: String, file: StaticString = #filePath, line: UInt = #line
    ) async throws {
        let reopened = AppPersistence(suiteName: suite)
        let actual = try await reopened.loadRestoreJournal()
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    func testAcceptedRestoreKeepsMismatchedXYTemperatureAndAbsentFixtureUntilFreshReadback() async throws {
        let suite = "hue-accepted-readback-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = AppPersistence(suiteName: suite)
        let model = AppModel(setupDefaults: defaults, persistence: persistence)
        model.profile = try BridgeProfile(bridgeID: bridge, host: "fixture.local")
        let original = room([light("xy"), light("white", mirek: 250), light("missing"), light("matched")])
        var accepted = RestoreJournal(bridgeID: bridge, area: original, lights: original.lights, createdAt: baselineDate)
        accepted.restoreAcceptedAt = baselineDate.addingTimeInterval(2)
        try await persistence.saveRestoreJournal(accepted)
        try await model.loadRecoveryState()
        XCTAssertTrue(model.hasRestorePoint)
        XCTAssertEqual(model.playback.snapshot.phase, .uncertain)

        let wrongColor = light("xy", x: 0.5)
        let wrongWhite = light("white", mirek: 270)
        await model.reconcileAcceptedRestore(in: [room([wrongColor, wrongWhite])], bridgeID: bridge)
        try await expectStored(accepted, in: suite)

        await model.reconcileAcceptedRestore(in: [room([wrongColor, wrongWhite, light("matched")])], bridgeID: bridge)
        var remaining = accepted
        remaining.snapshots.removeAll { $0.lightID.rawValue == "matched" }
        try await expectStored(remaining, in: suite)
        XCTAssertTrue(model.hasRestorePoint)
        XCTAssertEqual(model.restoreAreaID, original.id)
        XCTAssertEqual(model.playback.snapshot.phase, .uncertain)

        // XY retained on a temperature-mode fixture is immaterial once active mirek matches.
        await model.reconcileAcceptedRestore(in: [room([wrongColor, light("white", x: 0.6, mirek: 250)])], bridgeID: bridge)
        remaining.snapshots.removeAll { $0.lightID.rawValue == "white" }
        try await expectStored(remaining, in: suite)
        // A matching retained XY while another color mode is active still cannot confirm the XY baseline.
        await model.reconcileAcceptedRestore(in: [room([light("xy", mirek: 250), light("missing")])], bridgeID: bridge)
        remaining.snapshots.removeAll { $0.lightID.rawValue == "missing" }
        try await expectStored(remaining, in: suite)
        XCTAssertTrue(model.hasRestorePoint)

        await model.reconcileAcceptedRestore(in: [room([light("xy", x: 0.3001)])], bridgeID: bridge)
        try await expectStored(nil, in: suite)
        XCTAssertFalse(model.hasRestorePoint)
        XCTAssertFalse(model.foreignRecoveryPending)
        XCTAssertNil(model.restoreAreaID)
        XCTAssertEqual(model.playback.snapshot.mode, .idle)
        XCTAssertEqual(model.playback.snapshot.phase, .stopped)
        XCTAssertEqual(model.note, model.playback.snapshot.message)
        let lease = await model.playbackCoordinator.currentLease()
        XCTAssertNil(lease)
        #if DEBUG
        let attempts = await model.client.debugWriteAttempts
        XCTAssertEqual(attempts, 0)
        #endif
    }

    func testMatchingInventoryCannotClearUnacceptedOrForeignBaseline() async throws {
        let suite = "hue-guarded-readback-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = AppPersistence(suiteName: suite)
        let model = AppModel(setupDefaults: defaults, persistence: persistence)
        let profile = try BridgeProfile(bridgeID: bridge, host: "fixture.local")
        model.profile = profile
        let original = room([light("same-id")])
        var journal = RestoreJournal(bridgeID: bridge, area: original, lights: original.lights, createdAt: baselineDate)
        try await persistence.saveRestoreJournal(journal)
        try await model.loadRecoveryState()
        await model.reconcileAcceptedRestore(in: [original], bridgeID: bridge)
        try await expectStored(journal, in: suite)
        XCTAssertTrue(model.hasRestorePoint)

        journal.restoreAcceptedAt = baselineDate.addingTimeInterval(2)
        try await persistence.saveRestoreJournal(journal)
        await model.reconcileAcceptedRestore(in: [original], bridgeID: otherBridge)
        try await expectStored(journal, in: suite)
        model.profile = try BridgeProfile(bridgeID: otherBridge, host: "other-fixture.local")
        try await model.loadRecoveryState()
        let prior = model.playback.snapshot
        await model.reconcileAcceptedRestore(in: [original], bridgeID: bridge)
        await model.reconcileAcceptedRestore(in: [original], bridgeID: otherBridge)
        try await expectStored(journal, in: suite)
        XCTAssertTrue(model.foreignRecoveryPending)
        XCTAssertFalse(model.hasRestorePoint)
        XCTAssertNil(model.restoreAreaID)
        XCTAssertEqual(model.playback.snapshot, prior)
    }
}
