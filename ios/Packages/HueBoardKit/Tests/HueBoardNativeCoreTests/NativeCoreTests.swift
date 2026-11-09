import XCTest
import HueBoardKit
@testable import HueBoardNativeCore

final class NativeCoreTests: XCTestCase {
    private let bridgeID = "001788fffe123456"
    private let fingerprint = String(repeating: "ab", count: 32)

    func testProfileNormalizesIdentityAndPin() throws {
        let profile = try BridgeProfile(
            bridgeID: "00:17:88:FF:FE:12:34:56",
            host: "192.168.1.2",
            certificateSHA256: fingerprint.uppercased()
        )
        XCTAssertEqual(profile.bridgeID, bridgeID)
        XCTAssertEqual(profile.certificateSHA256, fingerprint)
        XCTAssertThrowsError(try BridgeProfile(bridgeID: "bad", host: "192.168.1.2"))
        XCTAssertThrowsError(try BridgeProfile(bridgeID: bridgeID, host: "8.8.8.8"))
    }

    func testLegacyProfileDecodesWithoutPinAndCanBeUpgraded() throws {
        let data = Data(
            """
            {"bridgeID":"001788FFFE123456","host":"192.168.1.2","port":443}
            """.utf8
        )
        let legacy = try JSONDecoder().decode(BridgeProfile.self, from: data)
        XCTAssertEqual(legacy.bridgeID, bridgeID)
        XCTAssertNil(legacy.certificateSHA256)
        let upgraded = try BridgeProfile(
            bridgeID: legacy.bridgeID,
            host: legacy.host,
            port: legacy.port,
            certificateSHA256: fingerprint
        )
        XCTAssertEqual(upgraded.certificateSHA256, fingerprint)
    }

    func testTLSIdentityRequiresExpectedBridgeAndPin() throws {
        let observation = try HueBridgeTLSIdentity.validate(
            subjectBridgeID: bridgeID.uppercased(),
            sha256: fingerprint,
            expectedBridgeID: bridgeID,
            pinnedSHA256: fingerprint
        )
        XCTAssertEqual(observation.bridgeID, bridgeID)
        XCTAssertEqual(observation.sha256, fingerprint)
        XCTAssertThrowsError(
            try HueBridgeTLSIdentity.validate(
                subjectBridgeID: bridgeID,
                sha256: fingerprint,
                expectedBridgeID: "001788fffe654321",
                pinnedSHA256: fingerprint
            )
        )
        XCTAssertThrowsError(
            try HueBridgeTLSIdentity.validate(
                subjectBridgeID: bridgeID,
                sha256: fingerprint,
                expectedBridgeID: bridgeID,
                pinnedSHA256: String(repeating: "cd", count: 32)
            )
        )
    }

    func testPersistence() async throws {
        let suite = "HueBoardTests.\(UUID())"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let persistence = AppPersistence(suiteName: suite)
        let profile = try BridgeProfile(
            bridgeID: bridgeID,
            host: "192.168.1.2",
            certificateSHA256: fingerprint
        )
        try await persistence.saveProfile(profile)
        let loaded = try await persistence.loadProfile()
        XCTAssertEqual(loaded, profile)
    }

    func testRestoreJournalCapturesOnlyNewlyTouchedLights() throws {
        let capturedAt = Date(timeIntervalSince1970: 100)
        let later = Date(timeIntervalSince1970: 200)
        let first = light("one", brightness: 25)
        let second = light("two", brightness: 75)
        let area = HueArea(
            id: .init(rawValue: "room"),
            kind: .room,
            name: "Room",
            lights: [first, second]
        )
        var journal = RestoreJournal(
            bridgeID: bridgeID,
            area: area,
            lights: [first],
            createdAt: capturedAt
        )

        XCTAssertEqual(
            try journal.captureMissing(
                from: area,
                touchedIDs: [first.id, second.id],
                capturedAt: later
            ),
            1
        )
        XCTAssertEqual(journal.capturedLightIDs, [first.id, second.id])
        XCTAssertEqual(journal.snapshots.first?.capturedAt, capturedAt)
        XCTAssertEqual(journal.snapshots.last?.capturedAt, later)
        XCTAssertEqual(
            try journal.captureMissing(from: area, touchedIDs: [first.id, second.id]),
            0
        )
        XCTAssertEqual(journal.snapshots.count, 2)
    }

    func testRestoreJournalRejectsAnotherArea() throws {
        let first = light("one", brightness: 25)
        let room = HueArea(
            id: .init(rawValue: "room"), kind: .room, name: "Room", lights: [first]
        )
        let zone = HueArea(
            id: .init(rawValue: "zone"), kind: .zone, name: "Zone", lights: [first]
        )
        var journal = RestoreJournal(bridgeID: bridgeID, area: room, lights: [first])
        XCTAssertThrowsError(
            try journal.captureMissing(from: zone, touchedIDs: [first.id])
        )
    }

    func testDescriptorBounds() throws {
        let profile = try BridgeProfile(
            bridgeID: bridgeID,
            host: "192.168.1.2",
            certificateSHA256: fingerprint
        )
        let area = HueArea(id: .init(rawValue: "r"), kind: .room, name: "R", lights: [])
        let descriptor = LiveSessionDescriptor(
            profile: profile,
            area: area,
            presetID: "x",
            brightness: 500,
            duration: 2
        )
        XCTAssertEqual(descriptor.brightness, 100)
        XCTAssertEqual(descriptor.duration, 60)
    }

    private func light(_ id: String, brightness: Double) -> HueLight {
        HueLight(
            id: .init(rawValue: id),
            ownerID: .init(rawValue: "device-\(id)"),
            name: id,
            isOn: true,
            brightness: brightness,
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
    }
}
