import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  func stopCoordinatedPlayback(reason: PlaybackStopReason) async {
    if let lease = activePlaybackLease, await playbackCoordinator.isCurrent(lease) {
      _ = await playbackCoordinator.stopCurrent(reason: reason)
    } else if await playbackCoordinator.currentLease() != nil {
      _ = await playbackCoordinator.stopCurrent(reason: reason)
    }
    activePlaybackLease = nil
  }

  func executeDirectFrame(
    _ actions: [HueResourceID: HueLightAction],
    profile: BridgeProfile,
    credential: HueBridgeCredential,
    areaID: HueResourceID,
    purpose: String
  ) async throws {
    guard !actions.isEmpty else {
      throw HueBoardError.unsupported("No eligible lights are available for \(purpose).")
    }
    let transport = DirectControlTransport(
      client: client,
      profile: profile,
      credential: credential,
      allowedLightIDs: Set(actions.keys)
    )
    let request = LightingPlaybackRequest(
      scope: .init(bridgeID: profile.bridgeID, areaID: areaID),
      transport: .directControl,
      presetID: purpose
    )
    let lease = try await playbackCoordinator.begin(request, using: transport)
    do {
      try await playbackCoordinator.submit(
        .init(sequence: 1, actions: actions),
        lease: lease
      )
      try await playbackCoordinator.finish(lease)
    } catch {
      if await playbackCoordinator.isCurrent(lease) {
        _ = await playbackCoordinator.stopCurrent(reason: .failed)
      }
      throw error
    }
  }

  func beginDirectControl(
    profile: BridgeProfile,
    credential: HueBridgeCredential,
    areaID: HueResourceID,
    allowedLightIDs: Set<HueResourceID>,
    purpose: String
  ) async throws -> PlaybackWriterLease {
    let transport = DirectControlTransport(
      client: client,
      profile: profile,
      credential: credential,
      allowedLightIDs: allowedLightIDs
    )
    return try await playbackCoordinator.begin(
      .init(
        scope: .init(bridgeID: profile.bridgeID, areaID: areaID),
        transport: .directControl,
        presetID: purpose
      ),
      using: transport
    )
  }

  func finishDirectControl(_ lease: PlaybackWriterLease) async {
    if await playbackCoordinator.isCurrent(lease) {
      do {
        try await playbackCoordinator.finish(lease)
      } catch {
        _ = await playbackCoordinator.stopCurrent(reason: .failed)
      }
    }
  }
}
