import XCTest
import HueBoardKit
@testable import HueBoardNativeCore

final class PhysicalLightSafetyStoreTests: XCTestCase {
    func testFreshStoreRequiresConsentAndUsesConservativeDefaults() async {
        let context = makeContext()
        defer { context.cleanup() }
        let store = PhysicalLightSafetyStore(suiteName: context.suite)
        let settings = await store.load()
        XCTAssertEqual(settings, .default)
        XCTAssertFalse(settings.warningAcknowledged)
        XCTAssertEqual(settings.maximumDynamicBrightness, 80)
    }

    func testSettingsRoundTripThroughIntegrityCheckedEnvelope() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let writer = PhysicalLightSafetyStore(suiteName: context.suite)
        let expected = PhysicalLightSafetySettings(
            warningAcknowledged: true,
            reduceLightMotion: true,
            maximumDynamicBrightness: 45
        )
        try await writer.save(expected)
        let reader = PhysicalLightSafetyStore(suiteName: context.suite)
        XCTAssertEqual(await reader.load(), expected)
        XCTAssertNotNil(context.defaults.data(forKey: "hue-board.native.physical-light-safety.v1"))
    }

    func testCorruptionFailsSafeAndQuarantinesRawRecord() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let store = PhysicalLightSafetyStore(suiteName: context.suite)
        try await store.save(
            .init(
                warningAcknowledged: true,
                reduceLightMotion: false,
                maximumDynamicBrightness: 100
            )
        )
        context.defaults.set(Data("tampered".utf8), forKey: "hue-board.native.physical-light-safety.v1")

        XCTAssertEqual(await store.load(), .default)
        XCTAssertNotNil(await store.quarantinedDataForTesting())
        XCTAssertNil(context.defaults.data(forKey: "hue-board.native.physical-light-safety.v1"))
    }

    private func makeContext() -> TestContext {
        let suite = "HueBoard.PhysicalLightSafetyStoreTests.\(UUID())"
        return .init(suite: suite, defaults: UserDefaults(suiteName: suite)!)
    }
}

private struct TestContext {
    let suite: String
    let defaults: UserDefaults

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
    }
}
