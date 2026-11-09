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
      if let profile { await persistence.saveSelectedAreaID(id, bridgeID: profile.bridgeID) }
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
    isBusy = true
    defer { isBusy = false }
    do {
      for light in area.lights where light.capabilities.power && !light.capabilities.streaming {
        try await client.updateLight(
          id: light.id,
          action: HueLightAction(on: .init(on: on)),
          profile: profile,
          credential: credential
        )
      }
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
      var accepted = 0
      var unresolved: [HueResourceID] = []
      for id in targetIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
        guard let light = byID[id], light.capabilities.power, !light.capabilities.streaming else {
          unresolved.append(id)
          continue
        }
        do {
          try await client.updateLight(
            id: id,
            action: HueLightAction(on: .init(on: false)),
            profile: profile,
            credential: credential
          )
          accepted += 1
        } catch {
          unresolved.append(id)
        }
      }

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
    isBusy = true
    defer { isBusy = false }
    do {
      for light in area.lights where light.capabilities.dimming && !light.capabilities.streaming {
        try await client.updateLight(
          id: light.id,
          action: HueLightAction(
            on: .init(on: true),
            dimming: .init(brightness: min(brightness, light.outputLimit)),
            dynamics: .init(duration: 500)
          ),
          profile: profile,
          credential: credential
        )
      }
      note = "Brightness commands accepted. Bridge readback will confirm reported state."
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
