import Foundation
import XCTest
import HueBoardKit
@testable import HueBoardAppleEngine

#if canImport(CryptoKit) && canImport(JavaScriptCore)
import CryptoKit
#endif

final class AppleEngineTests: XCTestCase {
#if canImport(CryptoKit) && canImport(JavaScriptCore)
    func testSharedRuntimeMatchesGeneratedParityDigest() async throws {
        let contract = try HueBoardContractLoader.load()
        let manifest = try HueEngineGoldenLoader.load()
        let engine = try JavaScriptHueEngine()

        XCTAssertEqual(manifest.schema, 2)
        XCTAssertEqual(manifest.release, contract.release)
        XCTAssertEqual(manifest.algorithm, "sha256")
        XCTAssertEqual(manifest.numberFormat, "fixed-11-posix")
        XCTAssertEqual(
            manifest.caseCount,
            contract.presets.count * manifest.times.count * manifest.positions.count
        )

        var canonical = ""
        var observed = 0
        for preset in contract.presets {
            var settings = HueEngineSettings.from(
                preset: preset,
                brightness: manifest.brightness
            )
            settings.seed = manifest.seed
            settings.topology = manifest.topology
            for time in manifest.times {
                for position in manifest.positions {
                    let frame = try await engine.sample(
                        time: time,
                        position: position,
                        settings: settings,
                        surge: 0
                    )
                    canonical += [
                        preset.id,
                        fixed(time),
                        fixed(position),
                        fixed(frame.color.red),
                        fixed(frame.color.green),
                        fixed(frame.color.blue),
                        fixed(frame.brightness),
                    ].joined(separator: "|") + "\n"
                    observed += 1
                }
            }
        }

        let digest = SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        XCTAssertEqual(observed, manifest.caseCount)
        XCTAssertEqual(digest, manifest.sha256)
    }

    func testParityAnchorFramesRemainInspectable() async throws {
        let contract = try HueBoardContractLoader.load()
        let manifest = try HueEngineGoldenLoader.load()
        let engine = try JavaScriptHueEngine()

        XCTAssertEqual(manifest.anchors.count, 8)
        for anchor in manifest.anchors {
            let preset = try XCTUnwrap(contract.preset(id: anchor.preset))
            var settings = HueEngineSettings.from(
                preset: preset,
                brightness: manifest.brightness
            )
            settings.seed = manifest.seed
            settings.topology = manifest.topology
            let frame = try await engine.sample(
                time: anchor.time,
                position: anchor.position,
                settings: settings,
                surge: 0
            )
            XCTAssertEqual(anchor.rgb.count, 3)
            XCTAssertEqual(frame.color.red, anchor.rgb[0], accuracy: 1e-9)
            XCTAssertEqual(frame.color.green, anchor.rgb[1], accuracy: 1e-9)
            XCTAssertEqual(frame.color.blue, anchor.rgb[2], accuracy: 1e-9)
            XCTAssertEqual(frame.brightness, anchor.brightness, accuracy: 1e-9)
        }
    }

    func testCustomPaletteRoundTripPreservesSharedEngineOutput() async throws {
        let contract = try HueBoardContractLoader.load()
        let palette = try XCTUnwrap(contract.palettes.first { $0.name == "Custom four-color" })
        let engine = try JavaScriptHueEngine()
        var draft = HueEngineSettings()
        draft.paletteA = palette.index
        draft.paletteB = palette.index
        let initialFrame = try await engine.sample(time: 7.25, position: 0.5, settings: draft)

        let customColors = ["#FF0000", "#EE2211", "#CC3311", "#AA4400"]
        draft.customColors = customColors
        let editedFrame = try await engine.sample(time: 7.25, position: 0.5, settings: draft)
        XCTAssertNotEqual(editedFrame.color, initialFrame.color)

        let document = HueSceneDocumentCodec.makeDocument(
            name: "Custom palette test",
            settings: HueSceneSettings(engineSettings: draft),
            source: .init(productVersion: contract.release, implementation: "native")
        )
        let encoded = try HueSceneDocumentCodec.encode(document, contract: contract)
        let restored = try HueSceneDocumentCodec.decode(encoded, contract: contract)
        let restoredSettings = restored.document.settings.nativeEngineSettings
        XCTAssertEqual(restoredSettings.customColors, customColors)
        XCTAssertEqual(restoredSettings.paletteA, palette.index)
        XCTAssertEqual(restoredSettings.paletteB, palette.index)
        let restoredFrame = try await engine.sample(
            time: 7.25, position: 0.5, settings: restoredSettings
        )
        XCTAssertEqual(restoredFrame, editedFrame)
    }

    private func fixed(_ input: Double) -> String {
        let value = abs(input) < 5e-12 ? 0 : input
        return String(
            format: "%.11f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
#else
    func testAppleEngineParityIsGatedToApplePlatforms() throws {
        XCTAssertThrowsError(try JavaScriptHueEngine())
    }
#endif
}
