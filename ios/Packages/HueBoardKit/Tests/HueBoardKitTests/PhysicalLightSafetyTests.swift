import XCTest
@testable import HueBoardKit

final class PhysicalLightSafetyTests: XCTestCase {
    func testDefaultSettingsAreConservativeAndRequireConsent() {
        let settings = PhysicalLightSafetySettings.default
        XCTAssertFalse(settings.warningAcknowledged)
        XCTAssertFalse(settings.reduceLightMotion)
        XCTAssertEqual(settings.maximumDynamicBrightness, 80)
    }

    func testBrightnessIsClampedToConfiguredDynamicMaximum() {
        let settings = PhysicalLightSafetySettings(
            warningAcknowledged: true,
            maximumDynamicBrightness: 42
        )
        XCTAssertEqual(
            PhysicalLightSafetyPolicy.clampedBrightness(100, settings: settings),
            42
        )
        XCTAssertEqual(
            PhysicalLightSafetyPolicy.clampedBrightness(-1, settings: settings),
            1
        )
    }

    func testReduceLightMotionBoundsEngineMotionWithoutChangingIdentity() throws {
        let contract = try HueBoardContractLoader.load()
        let preset = try XCTUnwrap(contract.presets.first)
        let original = HueEngineSettings.from(preset: preset, brightness: 100)
        let settings = PhysicalLightSafetySettings(
            warningAcknowledged: true,
            reduceLightMotion: true,
            maximumDynamicBrightness: 55
        )
        let adjusted = PhysicalLightSafetyPolicy.adjustedEngineSettings(
            original,
            safety: settings
        )

        XCTAssertEqual(adjusted.showA, original.showA)
        XCTAssertEqual(adjusted.paletteA, original.paletteA)
        XCTAssertLessThanOrEqual(adjusted.brightness, 55)
        XCTAssertLessThanOrEqual(adjusted.speed, 0.55)
        XCTAssertLessThanOrEqual(adjusted.energy, 45)
        XCTAssertLessThanOrEqual(adjusted.depth, 50)
        XCTAssertLessThanOrEqual(adjusted.tension, 55)
        XCTAssertEqual(adjusted.phaseOffset, 0)
    }

    func testReducedMotionUsesLongerRestTransitions() {
        let ordinary = PhysicalLightSafetyPolicy.restTransitionMilliseconds(
            lightCount: 6,
            settings: .default
        )
        let reduced = PhysicalLightSafetyPolicy.restTransitionMilliseconds(
            lightCount: 6,
            settings: .init(reduceLightMotion: true)
        )
        XCTAssertEqual(ordinary, 4_500)
        XCTAssertEqual(reduced, 8_000)
    }
}
