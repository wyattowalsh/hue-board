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

  @discardableResult
  func setAreaPower(_ on: Bool, in scope: LightingScope) async -> String? {
    guard profile?.bridgeID == scope.bridgeID, selectedArea?.id == scope.areaID else { return nil }
    guard canUseEverydayControls, let profile, let credential, let area = selectedArea else {
      if !canUseEverydayControls {
        errorMessage = "Stop and restore active playback before using everyday controls."
      }
      return nil
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
      let feedback = area.acceptanceMessage(for: on ? "power on" : "power off", count: actions.count)
      do {
        try await loadInventory(profile: profile, credential: credential)
      } catch {
        guard generation == emergencyGeneration else { return nil }
        errorMessage = "The Bridge accepted the power command, but light states could not refresh. \(error.localizedDescription)"
      }
      try checkControlIntent(generation)
      note = feedback
      return feedback
    } catch {
      guard generation == emergencyGeneration else { return nil }
      errorMessage = error.localizedDescription
      return nil
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

  @discardableResult
  func setAreaBrightness(_ value: Double, in scope: LightingScope) async -> String? {
    guard profile?.bridgeID == scope.bridgeID, selectedArea?.id == scope.areaID else { return nil }
    guard canUseEverydayControls, let profile, let credential, let area = selectedArea else {
      if !canUseEverydayControls {
        errorMessage = "Stop and restore active playback before changing brightness."
      }
      return nil
    }
    guard value.isFinite else {
      errorMessage = "Choose a brightness between 1% and 100%."
      return nil
    }
    let actions = area.roomBrightnessActions(for: value)
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
      let feedback = area.acceptanceMessage(for: "brightness", count: actions.count)
      note = feedback
      return feedback
    } catch {
      guard generation == emergencyGeneration else { return nil }
      errorMessage = error.localizedDescription
      return nil
    }
  }
}

extension HueLight {
  var canSetRoomBrightness: Bool {
    capabilities.power && capabilities.dimming && !capabilities.streaming && minimumBrightness <= outputLimit
  }
}

extension HueArea {
  var initialRoomBrightness: Double {
    let levels = lights.compactMap { light -> Double? in
      guard light.canSetRoomBrightness, light.isOn, let level = light.brightness, level.isFinite else { return nil }
      return min(max(level, 1), 100)
    }
    guard !levels.isEmpty else { return 50 }
    return (levels.reduce(0, +) / Double(levels.count)).rounded()
  }

  func roomBrightnessActions(for value: Double) -> [HueResourceID: HueLightAction] {
    let target = min(max(value, 1), 100)
    return Dictionary(uniqueKeysWithValues: lights.compactMap { light -> (HueResourceID, HueLightAction)? in
      guard light.canSetRoomBrightness else { return nil }
      let level = min(max(target, light.minimumBrightness), light.outputLimit)
      return (light.id, HueLightAction(on: .init(on: true), dimming: .init(brightness: level), dynamics: .init(duration: 500)))
    })
  }

  fileprivate func acceptanceMessage(for command: String, count: Int) -> String {
    let accepted = count == 1 ? "1 light" : "\(count) lights"
    let message = "Bridge accepted \(command) for \(accepted)."
    let skipped = lights.count - count
    return skipped > 0 ? "\(message) Skipped \(skipped)." : message
  }
}
