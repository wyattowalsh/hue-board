import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  func stopCoordinatedPlayback(reason: PlaybackStopReason) async {
    activePlaybackLease = nil
    _ = await playbackCoordinator.stopCurrent(reason: reason)
  }

  func checkControlIntent(_ generation: UInt64) throws {
    guard generation == emergencyGeneration, !emergencyOffInFlight else { throw CancellationError() }
  }

  func executeDirectFrame(
    _ actions: [HueResourceID: HueLightAction],
    profile: BridgeProfile,
    credential: HueBridgeCredential,
    areaID: HueResourceID,
    purpose: String,
    generation: UInt64
  ) async throws {
    guard !actions.isEmpty else {
      throw HueBoardError.unsupported("No eligible lights are available for \(purpose).")
    }
    let lease = try await beginDirectControl(profile: profile, credential: credential, areaID: areaID,
      allowedLightIDs: Set(actions.keys), purpose: purpose, generation: generation)
    do {
      try checkControlIntent(generation)
      try await playbackCoordinator.submit(.init(sequence: 1, actions: actions), lease: lease)
      try await playbackCoordinator.finish(lease)
    } catch {
      _ = await playbackCoordinator.stopCurrent(reason: .failed, matching: lease)
      throw error
    }
  }

  func beginDirectControl(
    profile: BridgeProfile,
    credential: HueBridgeCredential,
    areaID: HueResourceID,
    allowedLightIDs: Set<HueResourceID>,
    purpose: String,
    generation: UInt64
  ) async throws -> PlaybackWriterLease {
    try checkControlIntent(generation)
    let transport = DirectControlTransport(
      client: client, profile: profile, credential: credential, allowedLightIDs: allowedLightIDs
    )
    let lease = try await playbackCoordinator.begin(
      .init(scope: .init(bridgeID: profile.bridgeID, areaID: areaID), transport: .directControl, presetID: purpose),
      using: transport
    )
    do {
      // Direct transport preparation cannot send commands. Recheck the user's
      // intent after the actor hop before allowing its first submission.
      try checkControlIntent(generation)
      return lease
    } catch {
      _ = await playbackCoordinator.stopCurrent(reason: .cancelled, matching: lease)
      throw error
    }
  }

  func finishDirectControl(_ lease: PlaybackWriterLease) async {
    if await playbackCoordinator.isCurrent(lease) {
      do {
        try await playbackCoordinator.finish(lease)
      } catch {
        _ = await playbackCoordinator.stopCurrent(reason: .failed, matching: lease)
      }
    }
  }
}
