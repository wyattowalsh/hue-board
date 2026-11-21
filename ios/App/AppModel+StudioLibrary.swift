import Foundation
import HueBoardKit

@MainActor
extension AppModel {
    var studioSceneSettings: HueSceneSettings {
        var draft = studioSettings
        draft.brightness = brightness
        var settings = HueSceneSettings(engineSettings: draft)
        settings.sequenceIds = cueIDs
        settings.sequenceHold = cueHoldSeconds
        settings.sequenceOrder = cueOrder.rawValue
        return settings
    }

    func applyStudioSceneSettings(_ settings: HueSceneSettings) {
        studioSettings = settings.nativeEngineSettings
        brightness = studioSettings.brightness
        cueIDs = settings.sequenceIds
        cueHoldSeconds = settings.sequenceHold
        cueOrder = HueCueOrder(rawValue: settings.sequenceOrder) ?? .forward
    }

    @discardableResult
    func saveStudioMix(named rawName: String) -> Bool {
        guard studioLibraryIssue == nil else {
            errorMessage = "The saved Studio library has an unresolved validation error. Existing data was preserved; no replacement was written."
            return false
        }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80,
              !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            errorMessage = "Enter a mix name of 1 to 80 printable characters."
            return false
        }

        let document = HueSceneDocumentCodec.makeDocument(
            name: name,
            settings: studioSceneSettings,
            source: .init(
                productVersion: contract.release,
                implementation: "native"
            )
        )
        do {
            let updated = savedStudioDocuments + [document]
            try studioDocumentStore.save(updated, contract: contract)
            savedStudioDocuments = updated
            note = "Saved \(name) on this iPhone. Saving a draft never changes lights."
            return true
        } catch {
            errorMessage = "Could not save the Studio mix: \(error.localizedDescription)"
            return false
        }
    }

    func loadStudioMix(id: String) {
        guard !isLiveRunning else {
            errorMessage = "Stop the active Studio session before loading another mix."
            return
        }
        guard let document = savedStudioDocuments.first(where: { $0.documentId == id }) else {
            errorMessage = "That saved Studio mix is unavailable."
            return
        }
        do {
            try HueSceneDocumentCodec.validate(document, contract: contract)
            applyStudioSceneSettings(document.settings)
            isCueSequenceEnabled = false
            note = "Loaded \(document.name) into Studio. No light command was sent."
        } catch {
            errorMessage = "Saved mix could not be loaded: \(error.localizedDescription)"
        }
    }

    func deleteStudioMix(id: String) {
        guard studioLibraryIssue == nil else {
            errorMessage = "The saved library is in recovery mode; no entries will be deleted."
            return
        }
        guard let document = savedStudioDocuments.first(where: { $0.documentId == id }) else {
            return
        }
        do {
            let updated = savedStudioDocuments.filter { $0.documentId != id }
            try studioDocumentStore.save(updated, contract: contract)
            savedStudioDocuments = updated
            note = "Deleted local mix \(document.name). No Bridge changes were made."
        } catch {
            errorMessage = "Could not delete the Studio mix: \(error.localizedDescription)"
        }
    }
}
