import CryptoKit
import Foundation
import XCTest
import HueBoardKit
@testable import HueBoardAppleEngine

final class AppleEngineTests: XCTestCase {
#if canImport(JavaScriptCore)
    func testSharedRuntimeMatchesGeneratedParityDigest() async throws {
        let contract = try HueBoardContractLoader.load()
        let manifest = try HueEngineGoldenLoader.load()
        let engine = try JavaScriptHueEngine()

        XCTAssertEqual(manifest.schema, 1)
        XCTAssertEqual(manifest.release, contract.release)
        XCTAssertEqual(manifest.algorithm, "sha256")
        XCTAssertEqual(manifest.numberFormat, "fixed-12-posix")
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

    private func fixed(_ input: Double) -> String {
        let value = abs(input) < 5e-13 ? 0 : input
        return String(
            format: "%.12f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
#endif
}
