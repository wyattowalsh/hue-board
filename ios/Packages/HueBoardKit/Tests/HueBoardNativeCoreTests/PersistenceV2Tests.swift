import Foundation
import XCTest
import HueBoardKit
@testable import HueBoardNativeCore

final class PersistenceV2Tests: XCTestCase {
    private let bridgeID = "001788fffe123456"
    private let secondBridgeID = "001788fffe654321"
    private let fingerprint = String(repeating: "ab", count: 32)

    func testSHA256ReferenceVectors() {
        XCTAssertEqual(
            PersistenceChecksum.sha256Hex(Data()),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
        XCTAssertEqual(
            PersistenceChecksum.sha256Hex(Data("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testLegacyV1MigrationPreservesDataAndCreatesBackup() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let profile = try makeProfile(bridgeID: bridgeID, host: "192.168.1.2")
        let area = makeArea(id: "room-one")
        let journal = RestoreJournal(
            bridgeID: bridgeID,
            area: area,
            lights: area.lights,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let encoder = legacyEncoder()

        context.defaults.set(try encoder.encode(profile), forKey: "hue-board.native.profile.v1")
        context.defaults.set([bridgeID: area.id.rawValue], forKey: "hue-board.native.selected-area.v1")
        context.defaults.set(
            ["\(bridgeID)/\(area.id.rawValue)": "scene-one"],
            forKey: "hue-board.native.scene-registry.v1"
        )
        context.defaults.set(
            try encoder.encode(journal),
            forKey: "hue-board.native.restore-journal.v1"
        )

        let persistence = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        let loadedProfile = try await persistence.loadProfile()
        let loadedArea = try await persistence.loadSelectedAreaID(bridgeID: bridgeID)
        let loadedScene = try await persistence.sceneID(bridgeID: bridgeID, areaID: area.id)
        let loadedJournal = try await persistence.loadRestoreJournal()
        let hasBackup = await persistence.hasLegacyBackup()
        let report = await persistence.migrationReport()

        XCTAssertEqual(loadedProfile, profile)
        XCTAssertEqual(loadedArea, area.id)
        XCTAssertEqual(loadedScene, HueResourceID(rawValue: "scene-one"))
        XCTAssertEqual(loadedJournal, journal)
        XCTAssertTrue(hasBackup)
        XCTAssertEqual(report?.sourceSchema, 1)
        XCTAssertEqual(report?.targetSchema, 2)
        XCTAssertEqual(report?.quarantinedKeys, [])
        XCTAssertTrue(report?.legacyBackupCreated == true)

        XCTAssertNotNil(context.defaults.data(forKey: "hue-board.native.profile.v1"))
        XCTAssertNotNil(context.defaults.data(forKey: "hue-board.native.state.v2"))
        XCTAssertNotNil(context.defaults.data(forKey: "hue-board.native.recovery.v2"))

        let stateBefore = context.defaults.data(forKey: "hue-board.native.state.v2")
        let secondReader = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        let secondProfile = try await secondReader.loadProfile()
        XCTAssertEqual(secondProfile, profile)
        XCTAssertEqual(context.defaults.data(forKey: "hue-board.native.state.v2"), stateBefore)
    }

    func testMalformedLegacyRecordIsQuarantinedWithoutDestroyingOtherState() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        context.defaults.set(Data("not-json".utf8), forKey: "hue-board.native.profile.v1")
        context.defaults.set([bridgeID: "room-one"], forKey: "hue-board.native.selected-area.v1")

        let persistence = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        let profile = try await persistence.loadProfile()
        let selectedArea = try await persistence.loadSelectedAreaID(bridgeID: bridgeID)
        let quarantine = await persistence.quarantinedRecords()
        let report = await persistence.migrationReport()

        XCTAssertNil(profile)
        XCTAssertEqual(selectedArea, HueResourceID(rawValue: "room-one"))
        XCTAssertEqual(quarantine.count, 1)
        XCTAssertEqual(quarantine.first?.key, "hue-board.native.profile.v1")
        XCTAssertEqual(report?.quarantinedKeys, ["hue-board.native.profile.v1"])
    }

    func testChecksumMismatchFailsClosedAndQuarantinesRawState() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let profile = try makeProfile(bridgeID: bridgeID, host: "192.168.1.2")
        let writer = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        try await writer.saveProfile(profile)

        let key = "hue-board.native.state.v2"
        let original = try XCTUnwrap(context.defaults.data(forKey: key))
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: original) as? [String: Any]
        )
        object["payloadSHA256"] = String(repeating: "0", count: 64)
        let tampered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        context.defaults.set(tampered, forKey: key)

        let reader = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        do {
            _ = try await reader.loadProfile()
            XCTFail("Checksum mismatch must fail closed")
        } catch let error as PersistenceError {
            XCTAssertEqual(error, .checksumMismatch(key))
        }
        let quarantine = await reader.quarantinedRecords()
        XCTAssertEqual(quarantine.last?.key, key)
        XCTAssertEqual(quarantine.last?.rawData, tampered)
    }

    func testMultipleProfilesKeepSelectionsAndScenesIsolated() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let persistence = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        let first = try makeProfile(bridgeID: bridgeID, host: "192.168.1.2")
        let second = try makeProfile(bridgeID: secondBridgeID, host: "192.168.1.3")
        let area = HueResourceID(rawValue: "room")

        try await persistence.saveProfile(first)
        try await persistence.saveSelectedAreaID(.init(rawValue: "first-room"), bridgeID: first.bridgeID)
        try await persistence.saveSceneID(.init(rawValue: "first-scene"), bridgeID: first.bridgeID, areaID: area)
        try await persistence.saveProfile(second)
        try await persistence.saveSelectedAreaID(.init(rawValue: "second-room"), bridgeID: second.bridgeID)
        try await persistence.saveSceneID(.init(rawValue: "second-scene"), bridgeID: second.bridgeID, areaID: area)

        let activeSecond = try await persistence.loadProfile()
        let profiles = try await persistence.loadProfiles()
        let firstArea = try await persistence.loadSelectedAreaID(bridgeID: first.bridgeID)
        let secondArea = try await persistence.loadSelectedAreaID(bridgeID: second.bridgeID)
        let firstScene = try await persistence.sceneID(bridgeID: first.bridgeID, areaID: area)
        let secondScene = try await persistence.sceneID(bridgeID: second.bridgeID, areaID: area)

        XCTAssertEqual(activeSecond, second)
        XCTAssertEqual(profiles, [first, second])
        XCTAssertEqual(firstArea?.rawValue, "first-room")
        XCTAssertEqual(secondArea?.rawValue, "second-room")
        XCTAssertEqual(firstScene?.rawValue, "first-scene")
        XCTAssertEqual(secondScene?.rawValue, "second-scene")

        try await persistence.activateProfile(bridgeID: first.bridgeID)
        let activeFirst = try await persistence.loadProfile()
        XCTAssertEqual(activeFirst, first)
    }

    func testRecoveryIsIndependentAndRequiresExplicitDiscard() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let persistence = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        let profile = try makeProfile(bridgeID: bridgeID, host: "192.168.1.2")
        let area = makeArea(id: "room-one")
        let journal = RestoreJournal(
            bridgeID: bridgeID,
            area: area,
            lights: area.lights,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try await persistence.saveProfile(profile)
        try await persistence.saveRestoreJournal(journal)

        do {
            try await persistence.clearBridgeState(bridgeID: bridgeID)
            XCTFail("Recovery must block ordinary Bridge deletion")
        } catch let error as PersistenceError {
            XCTAssertEqual(error, .recoveryRequired(bridgeID))
        }
        let retainedProfile = try await persistence.loadProfile()
        let retainedJournal = try await persistence.loadRestoreJournal()
        XCTAssertEqual(retainedProfile, profile)
        XCTAssertEqual(retainedJournal, journal)

        try await persistence.clearBridgeState(bridgeID: bridgeID, discardRecovery: true)
        let removedProfile = try await persistence.loadProfile()
        let removedJournal = try await persistence.loadRestoreJournal()
        XCTAssertNil(removedProfile)
        XCTAssertNil(removedJournal)
    }

    func testRollbackRestoresLegacyBackupAndRemovesV2State() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let profile = try makeProfile(bridgeID: bridgeID, host: "192.168.1.2")
        context.defaults.set(
            try legacyEncoder().encode(profile),
            forKey: "hue-board.native.profile.v1"
        )
        let persistence = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        let migrated = try await persistence.loadProfile()
        XCTAssertEqual(migrated, profile)

        context.defaults.removeObject(forKey: "hue-board.native.profile.v1")
        try await persistence.rollbackToLegacyBackup()
        XCTAssertNotNil(context.defaults.data(forKey: "hue-board.native.profile.v1"))
        XCTAssertNil(context.defaults.data(forKey: "hue-board.native.state.v2"))
        XCTAssertNil(context.defaults.data(forKey: "hue-board.native.recovery.v2"))

        let remigrated = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        let remigratedProfile = try await remigrated.loadProfile()
        XCTAssertEqual(remigratedProfile, profile)
    }

    private func makeProfile(bridgeID: String, host: String) throws -> BridgeProfile {
        try BridgeProfile(
            bridgeID: bridgeID,
            host: host,
            certificateSHA256: fingerprint
        )
    }

    private func makeArea(id: String) -> HueArea {
        let light = HueLight(
            id: .init(rawValue: "light-\(id)"),
            ownerID: .init(rawValue: "device-\(id)"),
            name: "Test light",
            isOn: true,
            brightness: 42,
            color: .init(x: 0.3, y: 0.3),
            colorTemperatureMirek: nil,
            gamut: nil,
            capabilities: .init(
                power: true,
                dimming: true,
                color: true,
                colorTemperature: false,
                dynamicPalette: true
            )
        )
        return HueArea(
            id: .init(rawValue: id),
            kind: .room,
            name: "Test room",
            lights: [light]
        )
    }

    private func legacyEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private func makeContext() -> TestContext {
        let suite = "HueBoard.PersistenceV2Tests.\(UUID())"
        return TestContext(suite: suite, defaults: UserDefaults(suiteName: suite)!)
    }
}

private struct TestContext {
    let suite: String
    let defaults: UserDefaults

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
    }
}
