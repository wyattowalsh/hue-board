import HueBoardKit

public extension HueBridgeClient {
    /// Resolves a persisted scene ID without making a stale 404 fatal to Play.
    /// The core client currently surfaces HTTP status failures as `invalidResponse`;
    /// keep the compatibility translation isolated here until the transport gains
    /// a typed HTTP status error.
    func sceneIfPresent(
        id: HueResourceID,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws -> HueSceneResource? {
        do {
            return try await scene(id: id, profile: profile, credential: credential)
        } catch let error as HueBoardError {
            if case .invalidResponse(let message) = error,
               message.contains("HTTP 404")
            {
                return nil
            }
            throw error
        }
    }
}
