import Foundation
import HueBoardKit
import HueBoardNativeCore

struct HueLocalDiscovery: Sendable {
    func discover() async -> [HueBridgeCandidate] { preconditionFailure("Unexpected Bonjour access") }
}
struct KeychainVault {
    func credential(bridgeID: String) throws -> HueBridgeCredential? { preconditionFailure("Unexpected Keychain read") }
    func save(_ credential: HueBridgeCredential) throws { preconditionFailure("Unexpected Keychain write") }
    func removeCredential(bridgeID: String) throws { preconditionFailure("Unexpected Keychain removal") }
}
@MainActor final class SystemLightMotionPreference {
    let isEnabled = false
}
@MainActor final class StudioMicrophone {
    nonisolated var isCapturing: Bool { false }
    nonisolated func signal() -> HueLiveSignal { preconditionFailure("Unexpected microphone signal") }
    func start() async throws { preconditionFailure("Unexpected microphone start") }
    func stop() {}
}
@MainActor final class StudioMedia {
    var player: Never? { nil }
    func start(url: URL) async throws -> TimeInterval { preconditionFailure("Unexpected media start") }
    func signal() async throws -> HueLiveSignal { preconditionFailure("Unexpected media samples") }
    func verifyPlayback() throws { preconditionFailure("Unexpected media verification") }
    func play() { preconditionFailure("Unexpected media playback") }
    func stop() {}
}
final class ContinuedLiveCoordinator: Sendable {
    static let shared = ContinuedLiveCoordinator()
    typealias ProgressUpdate = @Sendable (Double, String) -> Void
    typealias Work = @Sendable (@escaping ProgressUpdate) async throws -> Void
    func submit(title: String, subtitle: String, work: @escaping Work) throws {
        preconditionFailure("Unexpected background task submission")
    }
    func cancel() {}
}
