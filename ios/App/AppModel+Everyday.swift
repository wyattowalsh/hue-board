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
    isBusy = true
    defer { isBusy = false }
    do {
      try await ensureRestoreJournal(profile: profile, area: area, touchedIDs: Set(actions.keys))
      try await executeDirectFrame(
        actions,
        profile: profile,
        credential: credential,
        areaID: area.id,
        purpose: on ? "everyday-power-on" : "everyday-power-off"
      )
      try await loadInventory(profile: profile, credential: credential)
      let skipped = area.lights.count - actions.count
      note = on
        ? "Power-on commands accepted for \(actions.count) lights. \(skipped) were skipped."
        : "Power-off commands accepted for \(actions.count) lights. \(skipped) were skipped."
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func turnOffNow() async {
    guard canTurnOffNow, let profile, let credential, let area = selectedArea else { return }
    emergencyOffInFlight = true
    isBusy = true
    defer {
      isBusy = false
      emergencyOffInFlight = false
    }
    foregroundLiveTask?.cancel()
    foregroundLiveTask = nil
    ContinuedLiveCoordinator.shared.cancel()
    await stopCoordinatedPlayback(reason: .user)

    do {
      let journal = try await persistence.loadRestoreJournal()
      let targetIDs: Set<HueResourceID>
      let commandAreaID: HueResourceID
      if let journal {
        guard journal.bridgeID == profile.bridgeID else {
          throw HueBoardError.unsupported(
            "The saved playback baseline belongs to another Bridge. Reconnect that Bridge and restore it before using emergency off here."
          )
        }
        targetIDs = journal.capturedLightIDs
        commandAreaID = journal.areaID
      } else {
        targetIDs = Set(area.lights.map(\.id))
        commandAreaID = area.id
      }
      guard !targetIDs.isEmpty else {
        throw HueBoardError.unsupported("No lights are available to turn off.")
      }

      var byID: [HueResourceID: HueLight] = [:]
      for light in areas.flatMap(\.lights) where byID[light.id] == nil {
        byID[light.id] = light
      }
      let eligibleIDs = Set(targetIDs.filter { id in
        guard let light = byID[id] else { return false }
        return light.capabilities.power && !light.capabilities.streaming
      })
      guard !eligibleIDs.isEmpty else {
        throw HueBoardError.unsupported(
          "No recoverable non-streaming lights are currently available for emergency off."
        )
      }

      let lease = try await beginDirectControl(
        profile: profile,
        credential: credential,
        areaID: commandAreaID,
        allowedLightIDs: eligibleIDs,
        purpose: "emergency-off"
      )
      var accepted = 0
      var unresolved = targetIDs.subtracting(eligibleIDs)
      var sequence: UInt64 = 0
      for id in eligibleIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
        sequence &+= 1
        do {
          try await playbackCoordinator.submit(
            .init(
              sequence: sequence,
              actions: [id: HueLightAction(on: .init(on: false))]
            ),
            lease: lease
          )
          accepted += 1
        } catch {
          unresolved.insert(id)
        }
      }
      await finishDirectControl(lease)

      guard accepted > 0 else {
        throw HueBoardError.network(
          "No emergency-off command was accepted. The saved baseline remains available."
        )
      }
      if unresolved.isEmpty {
        if journal != nil {
          playback.fail(
            "Playback lights were turned off. The saved baseline is retained; restore before new playback."
          )
        } else {
          playback.stop("Lights were turned off.")
        }
      } else {
        playback.fail(
          "Emergency off reached \(accepted) of \(targetIDs.count) lights. \(unresolved.count) were missing, streaming, or failed; the saved baseline is retained."
        )
        errorMessage = playback.snapshot.message
      }
      note = playback.snapshot.message
      try? await loadInventory(profile: profile, credential: credential)
    } catch {
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
    isBusy = true
    defer { isBusy = false }
    do {
      try await ensureRestoreJournal(profile: profile, area: area, touchedIDs: Set(actions.keys))
      try await executeDirectFrame(
        actions,
        profile: profile,
        credential: credential,
        areaID: area.id,
        purpose: "everyday-brightness"
      )
      let skipped = area.lights.count - actions.count
      note = "Brightness commands accepted for \(actions.count) lights. \(skipped) were skipped. Bridge readback is not measured light."
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
