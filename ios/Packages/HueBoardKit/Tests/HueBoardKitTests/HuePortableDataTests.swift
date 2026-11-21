import XCTest
@testable import HueBoardKit

final class HuePortableDataTests: XCTestCase {
    private let areaID = HueResourceID(rawValue: "synthetic-room")
    private let firstLight = HueResourceID(rawValue: "fixture-one")
    private let secondLight = HueResourceID(rawValue: "fixture-two")

    func testRoundTripsEveryDocumentKindAndCanonicalScene() throws {
        let contract = try HueBoardContractLoader.load()
        let look = try XCTUnwrap(contract.presets.first)
        let colors = ["#102030", "#204060", "#000000", "#FFFFFF"]
        var settings = HueSceneSettings(engineSettings: .from(preset: look, brightness: 37))
        settings.customColors = colors
        settings.sequenceIds = [look.id]
        let mix = HueSceneDocumentCodec.makeDocument(
            name: "Test mix",
            settings: settings,
            source: .init(productVersion: contract.release, implementation: "native")
        )
        let values: [HuePortableData] = [
            .studioDraft(.init(settings: settings, sourceLookID: look.id, duration: 600, cuesEnabled: true)),
            .customPalette(colors),
            .cues(.init(presetIDs: [look.id], holdSeconds: 45, order: .shuffle, seed: 2)),
            .mixLibrary([mix]),
            .favorites([look.id]),
            .roomLayout(.init(areaID: areaID, placements: [placement(firstLight, ceiling: 45)])),
            .safety(.init(reduceLightMotion: true, maximumDynamicBrightness: 65))
        ]
        for value in values {
            let data = try HuePortableDataCodec.encode(value, contract: contract)
            XCTAssertEqual(try HuePortableDataCodec.decode(data, contract: contract), value)
        }

        let canonical = try HueSceneDocumentCodec.encode(mix, contract: contract)
        XCTAssertEqual(try HuePortableDataCodec.decode(canonical, contract: contract), .mixLibrary([mix]))

        let legacy = Data(#"{"app":"hue-board","schema":3,"settings":{"brightness":46}}"#.utf8)
        let migrated = try HuePortableDataCodec.decode(legacy, contract: contract)
        guard case .mixLibrary(let library) = migrated else { return XCTFail("Expected an imported mix") }
        XCTAssertEqual(library.first?.settings.brightness, 46)
    }

    func testImportReviewCarriesStandaloneAndPerMemberMigrationWarnings() throws {
        let contract = try HueBoardContractLoader.load()
        let raw = Data(##"{"app":"hue-board","schema":3,"settings":{"brightness":150,"customColors":["#bad"]}}"##.utf8)
        let migrated = try HueSceneDocumentCodec.decode(raw, contract: contract)
        let standalone = try HuePortableDataCodec.decodeForReview(raw, contract: contract)
        XCTAssertEqual(standalone.warnings, migrated.warnings)
        XCTAssertTrue(standalone.warnings.contains("Clamped brightness to the supported range."))
        XCTAssertTrue(standalone.warnings.contains("Replaced invalid custom colors with defaults."))
        XCTAssertEqual(standalone.value, .mixLibrary([migrated.document]))
        XCTAssertEqual(try HuePortableDataCodec.decode(raw, contract: contract), standalone.value)

        let canonical = HueSceneDocumentCodec.makeDocument(name: "Existing canonical mix", settings: .init(),
                                                           source: .init(productVersion: contract.release, implementation: "native"))
        let canonicalBytes = try HueSceneDocumentCodec.encode(canonical, contract: contract)
        XCTAssertTrue(try HuePortableDataCodec.decodeForReview(canonicalBytes, contract: contract).warnings.isEmpty)
        let members = try [JSONSerialization.jsonObject(with: canonicalBytes), JSONSerialization.jsonObject(with: raw)]
        let library = try JSONSerialization.data(withJSONObject: [
            "format": "hue-board.native-data", "schema": 1, "kind": "mixLibrary", "payload": members
        ])
        let reviewed = try HuePortableDataCodec.decodeForReview(library, contract: contract)
        XCTAssertEqual(reviewed.warnings, migrated.warnings.map { "Mix 2: \($0)" })
        XCTAssertEqual(reviewed.value, .mixLibrary([canonical, migrated.document]))

        let encoded = try HuePortableDataCodec.encode(reviewed.value, contract: contract)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("Clamped brightness"))
        XCTAssertTrue(try HuePortableDataCodec.decodeForReview(encoded, contract: contract).warnings.isEmpty)
    }

    func testRejectsBadSchemaScopesFavoritesAndPayloadSize() throws {
        let contract = try HueBoardContractLoader.load()
        let badValues: [HuePortableData] = [
            .favorites(["unknown-look"]),
            .customPalette(["#FFFFFF"]),
            .safety(.init(reduceLightMotion: false, maximumDynamicBrightness: 105)),
            .roomLayout(.init(areaID: areaID, placements: [placement(firstLight, ceiling: 120)]))
        ]
        for value in badValues {
            XCTAssertThrowsError(try HuePortableDataCodec.encode(value, contract: contract))
        }
        let newer = Data(#"{"format":"hue-board.native-data","schema":2,"kind":"favorites","payload":[]}"#.utf8)
        XCTAssertThrowsError(try HuePortableDataCodec.decode(newer, contract: contract))
        let oversized = Data(repeating: 0, count: HuePortableDataCodec.maximumFileSize + 1)
        XCTAssertThrowsError(try HuePortableDataCodec.decode(oversized, contract: contract))
    }

    func testPaletteAndDraftImportsRejectColorsTheSharedEngineWouldIgnore() throws {
        let contract = try HueBoardContractLoader.load()
        let look = try XCTUnwrap(contract.presets.first)
        let settings = HueSceneSettings(engineSettings: .from(preset: look))
        let files: [HuePortableData] = [
            .customPalette(settings.customColors),
            .studioDraft(.init(settings: settings, sourceLookID: look.id, duration: 600, cuesEnabled: false))
        ]
        for file in files {
            let valid = try HuePortableDataCodec.encode(file, contract: contract)
            let json = String(decoding: valid, as: UTF8.self)
            let color = try XCTUnwrap(settings.customColors.first)
            XCTAssertTrue(json.contains(color))
            for malformed in ["#-12345", " \(color) "] {
                let changed = Data(json.replacingOccurrences(of: color, with: malformed).utf8)
                XCTAssertThrowsError(try HuePortableDataCodec.decode(changed, contract: contract), malformed)
            }
        }
    }

    func testLibraryImportIsIdempotentAndRejectsConflictsBeforeChangingAnyMix() throws {
        let contract = try HueBoardContractLoader.load()
        let source = HueSceneDocumentSource(productVersion: contract.release, implementation: "native")
        let first = HueSceneDocumentCodec.makeDocument(name: "First", settings: .init(), source: source)
        let second = HueSceneDocumentCodec.makeDocument(name: "Second", settings: .init(), source: source)
        let conflicting = HueSceneDocumentCodec.makeDocument(
            name: "Collision", settings: .init(), source: source, documentId: first.documentId
        )
        XCTAssertEqual(
            try HueSceneDocumentCodec.mergingLibrary([first, second], into: [first], contract: contract),
            [first, second]
        )
        XCTAssertThrowsError(try HueSceneDocumentCodec.mergingLibrary([second, conflicting], into: [first], contract: contract))
        XCTAssertThrowsError(try HueSceneDocumentCodec.mergingLibrary([first, first], into: [], contract: contract))
    }

    func testRoomMergePreservesUnspecifiedFixturesAndRejectsOtherRoomsOrFixtures() throws {
        let area = HueArea(id: areaID, kind: .room, name: "Synthetic room", lights: [])
        let first = placement(firstLight, ceiling: 70)
        let second = placement(secondLight, ceiling: 45)
        let current = HueRoomLayout(areaID: areaID, placements: [first, second])
        let adjusted = placement(firstLight, ceiling: 40)
        let imported = HueRoomLayout(areaID: areaID, placements: [adjusted])
        XCTAssertEqual(try current.mergingPlacements(from: imported, in: area).placements, [adjusted, second])

        let otherArea = HueRoomLayout(areaID: .init(rawValue: "other-room"), placements: [adjusted])
        XCTAssertThrowsError(try current.mergingPlacements(from: otherArea, in: area))
        let otherFixture = placement(.init(rawValue: "unrecognized-fixture"), ceiling: 90)
        let unknown = HueRoomLayout(areaID: areaID, placements: [otherFixture])
        XCTAssertThrowsError(try current.mergingPlacements(from: unknown, in: area))
    }

    func testSafetyTransferPreservesLocalWarningConsentAndOmitsItFromFile() throws {
        let contract = try HueBoardContractLoader.load()
        let preferences = HueSafetyPreferences(reduceLightMotion: true, maximumDynamicBrightness: 42)
        XCTAssertFalse(preferences.applying(to: .default).warningAcknowledged)
        XCTAssertTrue(preferences.applying(to: .init(warningAcknowledged: true)).warningAcknowledged)
        let data = try HuePortableDataCodec.encode(.safety(preferences), contract: contract)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("warningAcknowledged"))
    }

    private func placement(_ id: HueResourceID, ceiling: Double) -> HueFixturePlacement {
        .init(id: id, selected: false, x: 0.5, y: 0.5, phase: 0, trim: 0.75, ceiling: ceiling)
    }
}
