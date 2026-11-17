import XCTest
@testable import HueBoardKit

final class SceneDocumentTests: XCTestCase {
    private var contract: HueBoardContract {
        get throws { try HueBoardContractLoader.load() }
    }

    func testSchema2RoundTripIsScopeFreeAndComplete() throws {
        let contract = try contract
        var settings = HueSceneSettings()
        settings.brightness = 72
        let document = HueSceneDocumentCodec.makeDocument(
            name: "Evening test",
            settings: settings,
            source: HueSceneDocumentSource(
                productVersion: "6.0.0",
                engineABI: 1,
                catalogRevision: String(repeating: "a", count: 64),
                implementation: "native"
            ),
            documentId: "scene-evening",
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try HueSceneDocumentCodec.encode(document, contract: contract)
        let result = try HueSceneDocumentCodec.decode(data, contract: contract)

        XCTAssertEqual(result.source, .sceneSchema2)
        XCTAssertEqual(result.warnings, [])
        XCTAssertEqual(result.document, document)
        XCTAssertEqual(result.document.scope, .userSelected)
        XCTAssertEqual(result.document.settings.nativeEngineSettings.brightness, 72)

        let text = String(decoding: data, as: UTF8.self)
        for forbidden in [
            "applicationKey", "clientKey", "bridgeID", "bridgeId",
            "areaID", "areaId", "host", "ip"
        ] {
            XCTAssertFalse(text.contains("\"\(forbidden)\""), forbidden)
        }
    }

    func testSchema2RejectsPhysicalTargetAndUnknownSetting() throws {
        let contract = try contract
        let document = HueSceneDocumentCodec.makeDocument(
            name: "Safe",
            settings: HueSceneSettings(),
            source: HueSceneDocumentSource(
                productVersion: "6.0.0",
                implementation: "native"
            ),
            documentId: "safe-document",
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try HueSceneDocumentCodec.encode(document, contract: contract)
        var root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        root["bridgeID"] = "001788fffe123456"
        let targeted = try JSONSerialization.data(withJSONObject: root)
        XCTAssertThrowsError(try HueSceneDocumentCodec.decode(targeted, contract: contract))

        root.removeValue(forKey: "bridgeID")
        var settings = try XCTUnwrap(root["settings"] as? [String: Any])
        settings["unexpected"] = true
        root["settings"] = settings
        let unknownSetting = try JSONSerialization.data(withJSONObject: root)
        XCTAssertThrowsError(try HueSceneDocumentCodec.decode(unknownSetting, contract: contract))
    }

    func testLegacySchema3MigrationIsDeterministicAndClamped() throws {
        let contract = try contract
        let data = Data(
            """
            {
              "app": "BOYZ.EXE",
              "schema": 3,
              "settings": {
                "brightness": 999,
                "showA": "unknown",
                "palette": 2,
                "customColors": ["bad"]
              }
            }
            """.utf8
        )

        let first = try HueSceneDocumentCodec.decode(data, contract: contract)
        let second = try HueSceneDocumentCodec.decode(data, contract: contract)

        XCTAssertEqual(first.source, .legacyScriptable3)
        XCTAssertEqual(first.document, second.document)
        XCTAssertEqual(first.document.documentId, second.document.documentId)
        XCTAssertEqual(first.document.createdAt, "1970-01-01T00:00:00Z")
        XCTAssertEqual(first.document.settings.brightness, 100)
        XCTAssertEqual(first.document.settings.showA, "eclipse")
        XCTAssertEqual(first.document.settings.paletteA, 2)
        XCTAssertEqual(first.document.settings.customColors, HueSceneSettings().customColors)
        XCTAssertTrue(first.warnings.contains { $0.contains("legacy Scriptable schema 3") })
        XCTAssertTrue(first.warnings.contains { $0.contains("unknown primary pattern") })
    }

    func testSchema2RejectsInvalidEngineABIAndOutOfRangeSettings() throws {
        let contract = try contract
        let invalidABI = HueSceneDocumentCodec.makeDocument(
            name: "Bad ABI",
            settings: HueSceneSettings(),
            source: HueSceneDocumentSource(
                productVersion: "6.0.0",
                engineABI: 99,
                implementation: "native"
            ),
            documentId: "bad-abi",
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertThrowsError(try HueSceneDocumentCodec.encode(invalidABI, contract: contract))

        var invalidSettings = HueSceneSettings()
        invalidSettings.speed = 99
        let invalidSpeed = HueSceneDocumentCodec.makeDocument(
            name: "Bad speed",
            settings: invalidSettings,
            source: HueSceneDocumentSource(
                productVersion: "6.0.0",
                implementation: "native"
            ),
            documentId: "bad-speed",
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertThrowsError(try HueSceneDocumentCodec.encode(invalidSpeed, contract: contract))
    }
}
