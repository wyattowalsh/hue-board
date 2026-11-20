import Foundation
import HueBoardKit

@MainActor
extension AppModel {
    func setLightPower(_ id: HueResourceID, on: Bool) async {
        await applySingleLight(id, purpose: on ? "power-on" : "power-off") { light in
            guard light.capabilities.power else { return nil }
            return HueLightAction(on: .init(on: on))
        }
    }

    func setLightBrightness(_ id: HueResourceID, value: Double) async {
        guard value.isFinite else {
            errorMessage = "Brightness must be a finite value."
            return
        }
        await applySingleLight(id, purpose: "brightness") { light in
            guard light.capabilities.dimming,
                  light.minimumBrightness <= light.outputLimit else { return nil }
            let level = min(max(value, light.minimumBrightness), light.outputLimit)
            return HueLightAction(
                on: .init(on: true),
                dimming: .init(brightness: level),
                dynamics: .init(duration: 500)
            )
        }
    }

    func setLightColor(_ id: HueResourceID, rgb: RGB) async {
        guard rgb.components.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            errorMessage = "The selected color is invalid."
            return
        }
        await applySingleLight(id, purpose: "color") { light in
            guard light.capabilities.color else { return nil }
            let level = light.capabilities.dimming && light.minimumBrightness <= light.outputLimit
                ? HueDimmingAction(brightness: min(
                    max(light.brightness ?? 40, light.minimumBrightness), light.outputLimit
                ))
                : nil
            return HueLightAction(
                on: .init(on: true),
                dimming: level,
                color: .init(xy: HueColorMath.xy(rgb, gamut: light.gamut)),
                dynamics: .init(duration: 500)
            )
        }
    }

    func setLightTemperature(_ id: HueResourceID, mirek: Int) async {
        await applySingleLight(id, purpose: "white-temperature") { light in
            guard let range = light.supportedTemperatureRange,
                  range.contains(mirek) else { return nil }
            let level = light.capabilities.dimming && light.minimumBrightness <= light.outputLimit
                ? HueDimmingAction(brightness: min(
                    max(light.brightness ?? 40, light.minimumBrightness), light.outputLimit
                ))
                : nil
            return HueLightAction(
                on: .init(on: true),
                dimming: level,
                colorTemperature: .init(mirek: mirek),
                dynamics: .init(duration: 500)
            )
        }
    }

    private func applySingleLight(
        _ id: HueResourceID,
        purpose: String,
        makeAction: (HueLight) -> HueLightAction?
    ) async {
        guard canUseEverydayControls,
              let profile, let credential, let area = selectedArea else {
            errorMessage = "Stop and restore active playback before editing individual lights."
            return
        }
        guard let light = area.lights.first(where: { $0.id == id }) else {
            errorMessage = "The selected light is no longer in this room or zone."
            return
        }
        guard !light.capabilities.streaming else {
            errorMessage = "This light belongs to an active Entertainment stream. Hue Board will not override it."
            return
        }
        guard let action = makeAction(light) else {
            errorMessage = "The light cannot apply this control within its reported capabilities or output limits."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            try await ensureRestoreJournal(
                profile: profile,
                area: area,
                touchedIDs: [id]
            )
            try await executeDirectFrame(
                [id: action],
                profile: profile,
                credential: credential,
                areaID: area.id,
                purpose: "individual-\(purpose)"
            )
            note = "\(light.name): \(purpose) accepted by the Bridge."
            do {
                try await loadInventory(profile: profile, credential: credential)
            } catch {
                note = "\(light.name): command accepted, but readback failed. Check the actual light before sending another command."
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = "The light change is unconfirmed: \(error.localizedDescription) Inspect the physical light and Bridge readback before retrying."
        }
    }
}
