import HueBoardKit

public protocol HueLightUpdateSending: Sendable {
    func updateLight(
        id: HueResourceID,
        action: HueLightAction,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws
}

public protocol HueBridgePlaybackClient: HueLightUpdateSending {
    func inventory(
        profile: BridgeProfile,
        credential: HueBridgeCredential,
        outputLimits: [HueResourceID: Double]
    ) async throws -> [HueArea]

    func sceneIfPresent(
        id: HueResourceID,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws -> HueSceneResource?

    func createScene(
        _ scene: HueSceneCreateRequest,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws -> HueResourceID

    func updateScene(
        id: HueResourceID,
        scene: HueSceneUpdateRequest,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws

    func recallScene(
        id: HueResourceID,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws
}

extension HueBridgeClient: HueBridgePlaybackClient {}
