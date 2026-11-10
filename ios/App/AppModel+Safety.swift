import Foundation
import HueBoardKit

@MainActor
extension AppModel {
  func requiresDynamicLightConsent(for action: PendingDynamicAction) -> Bool {
    guard !safetySettings.warningAcknowledged else { return false }
    pendingDynamicAction = action
    isDynamicLightSafetyPresented = true
    return true
  }

  func confirmDynamicLightSafety() async {
    var updated = safetySettings
    updated.warningAcknowledged = true
    do {
      try await safetyStore.save(updated)
      safetySettings = updated
      let action = pendingDynamicAction
      pendingDynamicAction = nil
      isDynamicLightSafetyPresented = false
      switch action {
      case .bridge(let presetID):
        guard let preset = contract.preset(id: presetID) else {
          throw HueBoardError.missingResource("The selected look is no longer available.")
        }
        await play(preset)
      case .ambient:
        await startNativeLive()
      case nil:
        break
      }
    } catch {
      pendingDynamicAction = nil
      isDynamicLightSafetyPresented = false
      errorMessage = "Could not save the dynamic-light safety choice: \(error.localizedDescription)"
    }
  }

  func cancelDynamicLightSafety() {
    pendingDynamicAction = nil
    isDynamicLightSafetyPresented = false
  }

  func setReduceLightMotion(_ value: Bool) async {
    var updated = safetySettings
    updated.reduceLightMotion = value
    await saveSafetySettings(updated)
  }

  func setMaximumDynamicBrightness(_ value: Double) async {
    var updated = safetySettings
    updated.maximumDynamicBrightness = min(max(value, 10), 100)
    await saveSafetySettings(updated)
  }

  func showDynamicLightSafetyAgain() async {
    var updated = safetySettings
    updated.warningAcknowledged = false
    await saveSafetySettings(updated)
  }

  private func saveSafetySettings(_ value: PhysicalLightSafetySettings) async {
    do {
      try await safetyStore.save(value)
      safetySettings = value
    } catch {
      errorMessage = "Could not save physical-light safety settings: \(error.localizedDescription)"
    }
  }
}
