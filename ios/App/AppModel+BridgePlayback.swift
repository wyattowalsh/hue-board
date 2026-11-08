import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  func play(_ preset: HuePreset) async {
    guard canPlayScene, let profile, let credential, let area = selectedArea else { return }
    isBusy = true
    playback.beginBridge(presetID: preset.id)
    var sceneID: HueResourceID?
    defer { isBusy = false }
    do {
      let freshAreas = try await client.inventory(profile: profile, credential: credential)
      guard let freshArea = freshAreas.first(where: { $0.id == area.id }) else {
        throw HueBoardError.missingResource("The selected area is no longer available.")
      }
      let draft = try HueSceneBuilder.build(
        area: freshArea,
        preset: preset,
        contract: contract,
        brightness: brightness
      )
      try await ensureRestoreJournal(
        profile: profile,
        area: freshArea,
        touchedIDs: Set(draft.animatedLightIDs)
      )

      sceneID = await persistence.sceneID(bridgeID: profile.bridgeID, areaID: area.id)
      if let existing = sceneID {
        if let scene = try await client.scene(
          id: existing, profile: profile, credential: credential),
          scene.group?.resourceID == area.id,
          scene.group?.resourceType == area.kind.rawValue
        {
          try await client.updateScene(
            id: existing,
            scene: draft.update,
            profile: profile,
            credential: credential
          )
        } else {
          await persistence.saveSceneID(nil, bridgeID: profile.bridgeID, areaID: area.id)
          sceneID = nil
        }
      }
      if sceneID == nil {
        sceneID = try await client.createScene(
          draft.create,
          profile: profile,
          credential: credential
        )
        await persistence.saveSceneID(sceneID, bridgeID: profile.bridgeID, areaID: area.id)
      }
      guard let sceneID else { throw HueBoardError.invalidResponse("Scene identifier is missing.") }
      playback.markBridgeRequestPending(sceneID: sceneID)
      try await client.recallScene(id: sceneID, profile: profile, credential: credential)
      playback.markBridgeAccepted(sceneID: sceneID)
      selectedPresetID = preset.id
      note =
        "\(preset.name) was accepted by the Bridge and continues independently after you leave the app."
    } catch {
      playback.markUncertain(
        "Bridge playback is uncertain: \(error.localizedDescription) Stop and restore before retrying."
      )
      errorMessage = playback.snapshot.message
    }
  }
}
