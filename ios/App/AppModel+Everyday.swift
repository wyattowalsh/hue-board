import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  func selectArea(_ id: HueResourceID) async {
    guard canSwitchArea else {
      errorMessage = "Stop and restore the current area before switching rooms or zones."
      return
    }
    let previous = selectedAreaID
    selectedAreaID = id
    do {
      try await loadRecoveryState()
      if let profile { try await persistence.saveSelectedAreaID(id, bridgeID: profile.bridgeID) }
      loadCurrentRoomLayout()
    } catch {
      selectedAreaID = previous
      errorMessage = "Could not review restore state for the selected area: \(error.localizedDescription)"
    }
  }

  func setAreaPower(_ on: Bool) async {
    guard canUseEverydayControls, let profile, let credential, let area = selectedArea else {
      if !canUseEverydayControls {
        errorMessage = "Stop and restore active playback before using everyday controls."
      }
      return
    }
    let actions: [HueResourceID: HueLightAction] = Dictionary(
      uniqueKeysWithValues: area.lights.compactMap { light -> (HueResourceID, HueLightAction)? in
        guard light.capabilities.power, !light.capabilities.streaming else { return nil }
        return (light.id, HueLightAction(on: .init(on: on)))
      }
    )
    let generation = emergencyGeneration
    isBusy = true
    defer { if generation == emergencyGeneration { isBusy = false } }
    do {
      try await ensureRestoreJournal(profile: profile, area: area, touchedIDs: Set(actions.keys))
      try await executeDirectFrame(
        actions,
        profile: profile,
        credential: credential,
        areaID: area.id,
        purpose: on ? "everyday-power-on" : "everyday-power-off",
        generation: generation
      )
      try checkControlIntent(generation)
      try await loadInventory(profile: profile, credential: credential)
      let skipped = area.lights.count - actions.count
      note = on
        ? "Power-on commands accepted for \(actions.count) lights. \(skipped) were skipped."
        : "Power-off commands accepted for \(actions.count) lights. \(skipped) were skipped."
    } catch {
      guard generation == emergencyGeneration else { return }
      errorMessage = error.localizedDescription
    }
  }

  func turnOffNow() async {
    guard canTurnOffNow, let profile, let credential, let area = selectedArea else { return }
    emergencyGeneration &+= 1
    emergencyOffInFlight = true
    isBusy = true
    defer {
      isBusy = false
      emergencyOffInFlight = false
    }
    cancelStudioLiveSetupAndCapture()
    foregroundLiveTask?.cancel()
    foregroundLiveTask = nil
    ContinuedLiveCoordinator.shared.cancel()
    activePlaybackLease = nil
    let limits = preservedOutputCeilings()
    do {
      let result = try await EmergencyOffOperation.run(
        profile: profile, credential: credential, selectedArea: area, inventory: areas,
        client: client, coordinator: playbackCoordinator, persistence: persistence
      ) { [client] in
        let inventory = try await client.inventory(profile: profile, credential: credential, outputLimits: limits)
        return inventory.first(where: { $0.id == area.id })
      }
      hasRestorePoint = true
      restoreAreaID = result.areaID
      try? await loadInventory(profile: profile, credential: credential)
      if result.unresolved.isEmpty {
        playback.fail("Lights were turned off. The saved baseline is retained; restore before new playback.")
      } else {
        let count = result.accepted.count + result.unresolved.count
        playback.fail(
          "Emergency off reached \(result.accepted.count) of \(count) lights. \(result.unresolved.count) were missing, streaming, or failed; the saved baseline is retained."
        )
        errorMessage = playback.snapshot.message
      }
      note = playback.snapshot.message
    } catch {
      // A failed first write can still leave a newly captured baseline to restore.
      try? await loadRecoveryState()
      playback.fail("Emergency off was incomplete: \(error.localizedDescription)")
      errorMessage = playback.snapshot.message
    }
  }

  func setAreaBrightness(_ value: Double) async {
    guard canUseEverydayControls, let profile, let credential, let area = selectedArea else {
      if !canUseEverydayControls {
        errorMessage = "Stop and restore active playback before changing brightness."
      }
      return
    }
    brightness = min(max(value, 1), 100)
    let actions: [HueResourceID: HueLightAction] = Dictionary(
      uniqueKeysWithValues: area.lights.compactMap { light -> (HueResourceID, HueLightAction)? in
        guard light.capabilities.dimming, !light.capabilities.streaming,
              light.minimumBrightness <= light.outputLimit else { return nil }
        return (
          light.id,
          HueLightAction(
            on: .init(on: true),
            dimming: .init(brightness: min(max(brightness, light.minimumBrightness), light.outputLimit)),
            dynamics: .init(duration: 500)
          )
        )
      }
    )
    let generation = emergencyGeneration
    isBusy = true
    defer { if generation == emergencyGeneration { isBusy = false } }
    do {
      try await ensureRestoreJournal(profile: profile, area: area, touchedIDs: Set(actions.keys))
      try await executeDirectFrame(
        actions,
        profile: profile,
        credential: credential,
        areaID: area.id,
        purpose: "everyday-brightness",
        generation: generation
      )
      try checkControlIntent(generation)
      let skipped = area.lights.count - actions.count
      note = "Brightness commands accepted for \(actions.count) lights. \(skipped) were skipped. Bridge readback is not measured light."
    } catch {
      guard generation == emergencyGeneration else { return }
      errorMessage = error.localizedDescription
    }
  }
}
