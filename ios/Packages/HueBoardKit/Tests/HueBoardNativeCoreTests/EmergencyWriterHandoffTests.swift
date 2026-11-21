import Foundation
import HueBoardKit
import XCTest
@testable import HueBoardNativeCore

private actor EmergencyFixtureClient: HueLightUpdateSending {
    private let persistence: AppPersistence
    private let rejected: HueResourceID?
    private var writes: [String] = []
    private(set) var suspended = false
    private var release = false

    init(_ persistence: AppPersistence, rejected: HueResourceID? = nil) {
        self.persistence = persistence
        self.rejected = rejected
    }

    func updateLight(id: HueResourceID, action: HueLightAction, profile: BridgeProfile,
                     credential: HueBridgeCredential) async throws {
        let on = action.on?.on == true
        writes.append("\(id.rawValue) \(on ? "on" : "off")")
        if on {
            suspended = true
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while !release, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
            if !release { throw HueBoardError.network("Suspended test write timed out") }
        } else {
            let journal = try await persistence.loadRestoreJournal()
            guard journal?.capturedLightIDs.contains(id) == true, journal?.restoreAcceptedAt == nil else {
                throw HueBoardError.invalidResponse("Off arrived before a durable pending baseline")
            }
            if id == rejected { throw HueBoardError.network("Scripted rejection") }
        }
    }

    func resume() { release = true }
    func log() -> [String] { writes }
}

final class EmergencyWriterHandoffTests: XCTestCase {
    func testIdleOffUsesFreshReadbackOnlyForEligibleDisplayedFixtures() async throws {
        let context = try Context()
        defer { context.cleanUp() }
        let shown = room([light("a", 10), light("old", 15), light("stream", 18)])
        let fresh = room([light("a", 62), light("new", 44), light("stream", 80, streaming: true)])
        let client = EmergencyFixtureClient(context.persistence)
        let result = try await EmergencyOffOperation.run(
            profile: context.profile, credential: context.credential, selectedArea: shown,
            inventory: [shown], client: client, coordinator: context.coordinator, persistence: context.persistence
        ) { fresh }
        XCTAssertEqual(result.accepted, [id("a")])
        XCTAssertEqual(result.unresolved, [id("old"), id("stream")])
        let writes = await client.log()
        XCTAssertEqual(writes, ["a off"])
        let journal = try await context.persistence.loadRestoreJournal()
        XCTAssertEqual(journal?.capturedLightIDs, [id("a")])
        XCTAssertEqual(journal?.snapshots.first?.action.dimming?.brightness, 62)
    }

    func testPendingBaselineSurvivesDelayedWriterPartialOffAndImportAttempt() async throws {
        let context = try Context()
        defer { context.cleanUp() }
        let area = room([light("a", 23), light("b", 45), light("missing", 70)])
        let readback = room([light("a", 80), light("b", 85), light("unrelated", 85)])
        var original = RestoreJournal(bridgeID: context.profile.bridgeID, area: area, lights: area.lights)
        original.restoreAcceptedAt = Date()
        try await context.persistence.saveRestoreJournal(original)
        let captured = try await context.persistence.loadRestoreJournal()
        let client = EmergencyFixtureClient(context.persistence, rejected: id("b"))
        let prior = DirectControlTransport(client: client, profile: context.profile, credential: context.credential,
                                           allowedLightIDs: [id("a"), id("b")])
        let coordinator = context.coordinator
        let lease = try await coordinator.begin(.init(scope: .init(bridgeID: context.profile.bridgeID, areaID: area.id),
                                                      transport: .directControl, presetID: "synthetic"), using: prior)
        let advancing = Task {
            try await coordinator.submit(.init(sequence: 1, actions: [
                id("a"): .init(on: .init(on: true)), id("b"): .init(on: .init(on: true))
            ]), lease: lease)
        }
        try await waitFor { await client.suspended }
        let off = Task {
            try await EmergencyOffOperation.run(profile: context.profile, credential: context.credential,
                selectedArea: area, inventory: [readback], client: client,
                coordinator: coordinator, persistence: context.persistence) {
                    XCTFail("A known baseline must allow prompt emergency stop")
                    return nil
                }
        }
        try await waitFor { await prior.activeLease == nil }
        let beforeDrain = await client.log()
        XCTAssertEqual(beforeDrain, ["a on"])
        let canImport = try await context.persistence.isIdleForLocalImport()
        XCTAssertFalse(canImport)
        await client.resume()
        do {
            try await advancing.value
            XCTFail("The preempted advance must not resume")
        } catch PlaybackCoordinationError.staleLease(let old) {
            XCTAssertEqual(old, lease)
        }
        let result = try await off.value
        XCTAssertEqual(result.accepted, [id("a")])
        XCTAssertEqual(result.unresolved, [id("b"), id("missing")])
        let writes = await client.log()
        XCTAssertEqual(writes, ["a on", "a off", "b off"])
        let remaining = try await context.persistence.loadRestoreJournal()
        XCTAssertNil(remaining?.restoreAcceptedAt)
        XCTAssertEqual(remaining?.id, original.id)
        XCTAssertEqual(remaining?.snapshots, captured?.snapshots)
        let after = await coordinator.currentLease()
        XCTAssertNil(after)
        let mayImportAfterOff = try await context.persistence.isIdleForLocalImport()
        XCTAssertFalse(mayImportAfterOff)
    }

    func testBaselineAppearingDuringInventoryIsNeverOverwrittenByIdleOff() async throws {
        let context = try Context()
        defer { context.cleanUp() }
        let area = room([light("a", 54)])
        let earlier = room([light("a", 12)])
        let client = EmergencyFixtureClient(context.persistence)
        do {
            _ = try await EmergencyOffOperation.run(profile: context.profile, credential: context.credential,
                selectedArea: area, inventory: [area], client: client, coordinator: context.coordinator,
                persistence: context.persistence) {
                    _ = try await context.persistence.captureRestoreBaseline(
                        bridgeID: context.profile.bridgeID, area: earlier, touchedIDs: [id("a")])
                    return area
                }
            XCTFail("A stale nil-journal read must not authorize replacing a new baseline")
        } catch HueBoardError.unsupported {}
        let journal = try await context.persistence.loadRestoreJournal()
        XCTAssertEqual(journal?.snapshots.first?.action.dimming?.brightness, 12)
        let log = await client.log()
        XCTAssertTrue(log.isEmpty)
    }

    func testOverlappingCapturesAppendAndLateReadbackCannotClearNewBaseline() async throws {
        let context = try Context()
        defer { context.cleanUp() }
        let original = room([light("a", 11)])
        _ = try await context.persistence.captureRestoreBaseline(bridgeID: context.profile.bridgeID,
            area: original, touchedIDs: [id("a")])
        let before = try await context.persistence.loadRestoreJournal()
        let changed = room([light("a", 87), light("b", 21), light("c", 31)])
        async let left = context.persistence.captureRestoreBaseline(bridgeID: context.profile.bridgeID,
            area: changed, touchedIDs: [id("a"), id("b")])
        async let right = context.persistence.captureRestoreBaseline(bridgeID: context.profile.bridgeID,
            area: changed, touchedIDs: [id("a"), id("c")])
        _ = try await (left, right)
        let cleared = try await context.persistence.replaceRestoreJournal(nil, matching: before)
        XCTAssertFalse(cleared)
        let current = try await context.persistence.loadRestoreJournal()
        XCTAssertEqual(current?.capturedLightIDs, [id("a"), id("b"), id("c")])
        XCTAssertEqual(current?.snapshots.first(where: { $0.lightID == id("a") }), before?.snapshots.first)
    }

    func testUnreadableRecoveryRecordCannotBeSilentlyReplacedByIdleOff() async throws {
        let context = try Context()
        defer { context.cleanUp() }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: context.suite))
        let key = "hue-board.native.recovery.v2"
        defaults.set(["unexpected", "type"], forKey: key)
        let area = room([light("a", 54)])
        let client = EmergencyFixtureClient(context.persistence)
        do {
            _ = try await EmergencyOffOperation.run(profile: context.profile, credential: context.credential,
                selectedArea: area, inventory: [area], client: client,
                coordinator: context.coordinator, persistence: context.persistence) {
                    XCTFail("An unreadable recovery record must block new baseline capture")
                    return area
                }
            XCTFail("Expected unreadable recovery record")
        } catch HueBoardError.invalidResponse { }
        let log = await client.log()
        XCTAssertTrue(log.isEmpty)
        XCTAssertEqual(defaults.stringArray(forKey: key), ["unexpected", "type"])
    }

    func testIdleReadFailureSendsNoOffAndCreatesNoBaseline() async throws {
        let context = try Context()
        defer { context.cleanUp() }
        let area = room([light("a", 20)])
        let client = EmergencyFixtureClient(context.persistence)
        do {
            _ = try await EmergencyOffOperation.run(profile: context.profile, credential: context.credential,
                selectedArea: area, inventory: [area], client: client,
                coordinator: context.coordinator, persistence: context.persistence) {
                    throw HueBoardError.network("Scripted lost inventory")
                }
            XCTFail("Idle Off must preserve an unreadable baseline")
        } catch HueBoardError.network { }
        let writes = await client.log()
        let journal = try await context.persistence.loadRestoreJournal()
        XCTAssertTrue(writes.isEmpty)
        XCTAssertNil(journal)
    }
}

private struct Context: Sendable {
    let suite = "HueBoard.EmergencyHandoff.\(UUID())"
    let persistence: AppPersistence
    let coordinator = PlaybackCoordinator()
    let profile: BridgeProfile
    let credential: HueBridgeCredential

    init() throws {
        persistence = AppPersistence(suiteName: suite, writerVersion: "test")
        profile = try BridgeProfile(bridgeID: "001788fffe123456", host: "192.168.1.2",
                                    certificateSHA256: String(repeating: "cd", count: 32))
        credential = .init(bridgeID: profile.bridgeID, applicationKey: "synthetic")
    }

    func cleanUp() { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
}

private func waitFor(_ condition: () async -> Bool) async throws {
    let expiry = ContinuousClock.now.advanced(by: .seconds(4))
    while !(await condition()) {
        guard ContinuousClock.now < expiry else { throw HueBoardError.invalidResponse("Synthetic writer wait expired.") }
        try await Task.sleep(for: .milliseconds(5))
    }
}

private func id(_ raw: String) -> HueResourceID { .init(rawValue: raw) }
private func room(_ lights: [HueLight]) -> HueArea {
    .init(id: id("test-room"), kind: .room, name: "Test room", lights: lights)
}
private func light(_ name: String, _ brightness: Double, streaming: Bool = false) -> HueLight {
    .init(id: id(name), ownerID: nil, name: name, isOn: true, brightness: brightness,
          color: .init(x: 0.32, y: 0.31), colorTemperatureMirek: nil, gamut: nil,
          capabilities: .init(power: true, dimming: true, color: true,
                              colorTemperature: false, dynamicPalette: false, streaming: streaming))
}
