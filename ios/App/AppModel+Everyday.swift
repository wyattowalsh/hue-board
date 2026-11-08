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
        selectedAreaID = id
        if let profile { await persistence.saveSelectedAreaID(id, bridgeID: profile.bridgeID) }
        try? await loadRecoveryState()
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
