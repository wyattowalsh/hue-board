import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  func play(_ preset: HuePreset) async {
    guard canPlayScene else { return }
    guard let profile = self.profile else { return }
    guard let credential = self.credential else { return }
    guard let area = selectedArea else { return }
    isBusy = true
    playback.beginBridge(presetID: preset.id)
    var sceneID: HueResourceID?
    var sceneMutationAttempted = false
    var recallAttempted = false
    defer { isBusy = false }
    do {
      let freshAreas: [HueArea] = try await client.inventory(
        profile: profile, credential: credential)
      guard let freshArea = freshAreas.first(where: { $0.id == area.id }) else {
        throw HueBoardError.missingResource("The selected area is no longer available.")
      }
      let draft = try HueSceneBuilder.build(
        area: freshArea,
        preset: preset,
        contract: contract,
        brightness: brightness
      )

      sceneID = try await persistence.sceneID(bridgeID: profile.bridgeID, areaID: area.id)
      if let existing = sceneID {
        if let scene = try await client.sceneIfPresent(
          id: existing, profile: profile, credential: credential),
          scene.group?.resourceID == area.id,
          scene.group?.resourceType == area.kind.rawValue
        {
          // The resource identity is valid. Mutation happens only after baseline capture.
        } else {
          try await persistence.saveSceneID(nil, bridgeID: profile.bridgeID, areaID: area.id)
          sceneID = nil
        }
      }

      // Capture every light that the next scene may touch before creating, updating,
      // or recalling a Bridge resource. Updating an already-active scene may affect
      // physical output on some firmware, so it is not treated as an inert operation.
      try await ensureRestoreJournal(
        profile: profile,
        area: freshArea,
        touchedIDs: Set(draft.animatedLightIDs)
      )

      if let existing = sceneID {
        sceneMutationAttempted = true
        try await client.updateScene(
          id: existing,
          scene: draft.update,
          profile: profile,
          credential: credential
        )
      } else {
        sceneMutationAttempted = true
        sceneID = try await client.createScene(
          draft.create,
          profile: profile,
          credential: credential
        )
        try await persistence.saveSceneID(sceneID, bridgeID: profile.bridgeID, areaID: area.id)
      }
      guard let sceneID else { throw HueBoardError.invalidResponse("Scene identifier is missing.") }

      playback.markBridgeRequestPending(sceneID: sceneID)
      recallAttempted = true
      try await client.recallScene(id: sceneID, profile: profile, credential: credential)
      playback.markBridgeAccepted(sceneID: sceneID)
      selectedPresetID = preset.id
      note =
        "\(preset.name) was accepted by the Bridge and continues independently after you leave the app."
    } catch {
      if recallAttempted {
        playback.markUncertain(
          "Bridge scene recall is uncertain: \(error.localizedDescription) Stop and restore before retrying."
        )
      } else if sceneMutationAttempted {
        playback.markUncertain(
          "Bridge scene preparation is uncertain: \(error.localizedDescription) No recall was confirmed; stop and restore before retrying."
        )
      } else {
        playback.stop(
          "Could not prepare Bridge playback: \(error.localizedDescription) No scene mutation or recall was sent."
        )
      }
      errorMessage = playback.snapshot.message
    }
  }
}
