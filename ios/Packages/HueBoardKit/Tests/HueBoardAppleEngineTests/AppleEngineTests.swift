import XCTest
import HueBoardKit
@testable import HueBoardAppleEngine

final class AppleEngineTests: XCTestCase {
#if canImport(JavaScriptCore)
    func testSharedRuntimeMatchesKnownSourceFrame() async throws {
        let contract = try HueBoardContractLoader.load()
        let preset = try XCTUnwrap(contract.preset(id: "ion-eclipse"))
        let engine = try JavaScriptHueEngine()
        let frame = try await engine.sample(time: 0, position: 0, settings: .from(preset: preset, brightness: 72), surge: 0)
        XCTAssertEqual(frame.color.red, 0.04631401138111891, accuracy: 1e-12)
        XCTAssertEqual(frame.color.green, 0.20974335962373003, accuracy: 1e-12)
        XCTAssertEqual(frame.color.blue, 0.7416042037012389, accuracy: 1e-12)
        XCTAssertEqual(frame.brightness, 31.541258221453813, accuracy: 1e-12)
    }
#endif
}
