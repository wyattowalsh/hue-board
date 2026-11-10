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
      try await executeDirectFrame(
        actions,
        profile: profile,
        credential: credential,
        areaID: area.id,
        purpose: on ? "everyday-power-on" : "everyday-power-off"
      )
      try await loadInventory(profile: profile, credential: credential)
      note = on ? "Power-on commands accepted." : "Power-off commands accepted."
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func turnOffNow() async {
    guard canTurnOffNow, let profile, let credential, let area = selectedArea else { return }
    foregroundLiveTask?.cancel()
    foregroundLiveTask = nil
    ContinuedLiveCoordinator.shared.cancel()
    await stopCoordinatedPlayback(reason: .user)
    isBusy = true
    defer { isBusy = false }

    do {
      let journal = try await persistence.loadRestoreJournal()
      let targetIDs: Set<HueResourceID>
      if let journal {
        guard journal.bridgeID == profile.bridgeID, journal.areaID == area.id else {
          throw HueBoardError.unsupported(
            "The saved playback baseline belongs to another Bridge or area. Restore it before using emergency off here."
          )
        }
        targetIDs = journal.capturedLightIDs
      } else {
        targetIDs = Set(area.lights.map(\.id))
      }
      guard !targetIDs.isEmpty else {
        throw HueBoardError.unsupported("No lights are available to turn off.")
      }

      let byID = Dictionary(uniqueKeysWithValues: area.lights.map { ($0.id, $0) })
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
        areaID: area.id,
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
        guard light.capabilities.dimming, !light.capabilities.streaming else { return nil }
        return (
          light.id,
          HueLightAction(
            on: .init(on: true),
            dimming: .init(brightness: min(brightness, light.outputLimit)),
            dynamics: .init(duration: 500)
          )
        )
      }
    )
    isBusy = true
    defer { isBusy = false }
    do {
      try await executeDirectFrame(
        actions,
        profile: profile,
        credential: credential,
        areaID: area.id,
        purpose: "everyday-brightness"
      )
      note = "Brightness commands accepted. Bridge readback will confirm reported state."
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
