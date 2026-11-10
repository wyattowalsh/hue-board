import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  func play(_ preset: HuePreset) async {
    guard canPlayScene else { return }
    guard !requiresDynamicLightConsent(for: .bridge(presetID: preset.id)) else { return }
    guard let profile, let credential, let area = selectedArea else { return }
    isBusy = true
    playback.beginBridge(presetID: preset.id)
    let replacedExistingPlayback = activePlaybackLease != nil
    defer { isBusy = false }

    await stopCoordinatedPlayback(reason: .replaced)
    let transport = BridgeSceneTransport(
      client: client,
      persistence: persistence,
      profile: profile,
      credential: credential,
      contract: contract,
      preset: preset,
      brightness: effectiveDynamicBrightness
    )
    let request = LightingPlaybackRequest(
      scope: .init(bridgeID: profile.bridgeID, areaID: area.id),
      transport: .bridgeScene,
      presetID: preset.id
    )

    do {
      let lease = try await playbackCoordinator.begin(request, using: transport)
      activePlaybackLease = lease
      hasRestorePoint = true
      restoreAreaID = area.id

      switch await transport.outcome() {
      case .accepted(let sceneID):
        playback.markBridgeRequestPending(sceneID: sceneID)
        playback.markBridgeAccepted(sceneID: sceneID)
        selectedPresetID = preset.id
        note =
          "\(preset.name) was accepted by the Bridge and continues independently after you leave the app."
      case .uncertain(let sceneID, let message):
        if let sceneID { playback.markBridgeRequestPending(sceneID: sceneID) }
        playback.markUncertain(message)
        note = message
        errorMessage = message
      case .prepared, .idle:
        playback.markUncertain(
          "Bridge playback returned without a final accepted or uncertain outcome. Stop and restore before retrying."
        )
        note = playback.snapshot.message
        errorMessage = playback.snapshot.message
      }
    } catch {
      activePlaybackLease = nil
      if let journal = try? await persistence.loadRestoreJournal(),
         journal.bridgeID == profile.bridgeID,
         journal.areaID == area.id
      {
        hasRestorePoint = true
        restoreAreaID = area.id
      }
      if replacedExistingPlayback || hasRestorePoint {
        playback.markUncertain(
          "Could not prepare the new Bridge scene: \(error.localizedDescription) Previous output may still be active; stop and restore before retrying."
        )
      } else {
        playback.stop(
          "Could not prepare Bridge playback: \(error.localizedDescription) No scene mutation or recall was sent."
        )
      }
      note = playback.snapshot.message
      errorMessage = playback.snapshot.message
    }
  }
}
