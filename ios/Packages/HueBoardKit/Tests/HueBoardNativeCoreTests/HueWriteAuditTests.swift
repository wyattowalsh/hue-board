#if DEBUG
import HueBoardKit
import HueBoardNativeCore
import XCTest

@MainActor
final class HueWriteAuditTests: XCTestCase {
    func testEachLightingMutatorCountsOneAttemptBeforeTransport() async throws {
        let client = HueBridgeClient()
        // The missing certificate pin rejects every v2 call before making a URLRequest.
        let profile = try BridgeProfile(bridgeID: "001788fffe123456", host: "synthetic-hue-audit.local")
        XCTAssertNil(profile.certificateSHA256)
        let credential = HueBridgeCredential(bridgeID: profile.bridgeID, applicationKey: "synthetic")
        let id = HueResourceID(rawValue: "synthetic-lamp")
        let light = HueLight(id: id, ownerID: nil, name: "Sample", isOn: true, brightness: 30,
                             color: nil, colorTemperatureMirek: nil, gamut: nil,
                             capabilities: .init(power: true, dimming: true, color: true,
                                                 colorTemperature: false, dynamicPalette: true))
        let area = HueArea(id: .init(rawValue: "synthetic-room"), kind: .room, name: "Sample room", lights: [light])
        let contract = try HueBoardContractLoader.load()
        let preset = try XCTUnwrap(contract.preset(id: "ion-eclipse"))
        let scene = try HueSceneBuilder.build(area: area, preset: preset, contract: contract, brightness: 20)

        @MainActor func rejected(_ expected: UInt64, _ run: @MainActor () async throws -> Void) async throws {
            do {
                try await run()
                XCTFail("An unpinned fixture reached a successful response")
            } catch HueBoardError.authorization(let message) {
                XCTAssertTrue(message.contains("certificate"))
            }
            let count = await client.debugWriteAttempts
            XCTAssertEqual(count, expected)
        }

        try await rejected(0) { _ = try await client.scene(id: id, profile: profile, credential: credential) }
        try await rejected(1) { _ = try await client.createScene(scene.create, profile: profile, credential: credential) }
        try await rejected(2) { try await client.updateScene(id: id, scene: scene.update, profile: profile, credential: credential) }
        try await rejected(3) { try await client.recallScene(id: id, profile: profile, credential: credential) }
        try await rejected(4) { try await client.updateLight(id: id, action: .init(), profile: profile, credential: credential) }
    }
}
#endif
