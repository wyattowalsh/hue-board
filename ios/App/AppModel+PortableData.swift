import Foundation
import HueBoardKit

@MainActor
extension AppModel {
    var canImportPortableData: Bool {
        !isBusy && !isLiveRunning && !hasRestorePoint && !requiresRecovery
            && playbackSnapshot.mode != .bridge && !emergencyOffInFlight
    }

    var portableStudioDraft: HuePortableData {
        .studioDraft(.init(
            settings: studioSceneSettings,
            sourceLookID: selectedPresetID,
            duration: liveDuration,
            cuesEnabled: isCueSequenceEnabled
        ))
    }

    var portableCues: HuePortableData {
        .cues(.init(presetIDs: cueIDs, holdSeconds: cueHoldSeconds, order: cueOrder, seed: studioSettings.seed))
    }

    var portableSafety: HuePortableData {
        .safety(.init(
            reduceLightMotion: safetySettings.reduceLightMotion,
            maximumDynamicBrightness: safetySettings.maximumDynamicBrightness
        ))
    }

    func reviewPortableImport(_ value: HuePortableData) throws -> String {
        try requireIdleTransfer()
        switch value {
        case .studioDraft:
            return "Replace the current Studio draft, including its palette, cues and session duration?"
        case .customPalette:
            return "Replace the four custom colors in your current Studio draft?"
        case .cues(let sequence):
            return "Replace the Studio cue list with \(sequence.presetIDs.count) cues and use the file’s hold time, order and seed?"
        case .mixLibrary(let documents):
            let merged = try mergedLibrary(documents)
            let additions = merged.count - savedStudioDocuments.count
            if additions == 0 { return "All mixes in this file are already in your Studio library." }
            return "Import \(additions) new mix\(additions == 1 ? "" : "es")? Existing mixes stay in the library."
        case .favorites(let ids):
            return "Replace your Scenes favorites with the \(ids.count) in this file?"
        case .roomLayout(let imported):
            let (current, updated, area) = try roomImport(imported)
            let prior = Dictionary(uniqueKeysWithValues: current.placements.map { ($0.id, $0) })
            let changes = updated.placements.filter { $0 != prior[$0.id] }
            let changedCeilings = changes.filter { $0.ceiling != prior[$0.id]?.ceiling }.count
            let raisedCeilings = changes.filter { $0.ceiling > (prior[$0.id]?.ceiling ?? 100) }.count
            return "Update \(changes.count) fixture placements in \(area.name)? "
                + "This changes \(changedCeilings) brightness ceilings, including \(raisedCeilings) increases."
        case .safety(let preferences):
            let motion = preferences.reduceLightMotion ? "on" : "off"
            let brightness = preferences.maximumDynamicBrightness.formatted()
            return "Set Reduce Light Motion to \(motion) and maximum dynamic brightness to \(brightness)%?"
        }
    }

    func applyPortableImport(_ value: HuePortableData) async throws {
        try requireIdleTransfer()
        switch value {
        case .studioDraft(let draft):
            applyStudioSceneSettings(draft.settings)
            selectedPresetID = draft.sourceLookID
            liveDuration = draft.duration
            isCueSequenceEnabled = draft.cuesEnabled
        case .customPalette(let colors):
            studioSettings.customColors = colors
        case .cues(let sequence):
            cueIDs = sequence.presetIDs
            cueHoldSeconds = sequence.holdSeconds
            cueOrder = sequence.order
            studioSettings.seed = sequence.seed
            if cueIDs.isEmpty { isCueSequenceEnabled = false }
        case .mixLibrary(let documents):
            let merged = try mergedLibrary(documents)
            guard merged != savedStudioDocuments else { return }
            try studioDocumentStore.save(merged, contract: contract)
            savedStudioDocuments = merged
        case .favorites(let ids):
            saveFavoritePresets(Set(ids))
        case .roomLayout(let imported):
            let (_, updated, area) = try roomImport(imported)
            guard let profile else { throw HueBoardError.unsupported("Reconnect the original Bridge to import this layout.") }
            try roomLayoutStore.save(updated, bridgeID: profile.bridgeID, area: area)
            roomLayout = updated
        case .safety(let preferences):
            let updated = preferences.applying(to: safetySettings)
            isBusy = true
            defer { isBusy = false }
            try await safetyStore.save(updated)
            safetySettings = updated
        }
    }

    private func requireIdleTransfer() throws {
        guard canImportPortableData else {
            throw HueBoardError.unsupported("Imports require idle playback and resolved recovery.")
        }
    }

    private func mergedLibrary(_ documents: [HueSceneDocument]) throws -> [HueSceneDocument] {
        guard studioLibraryIssue == nil else {
            throw HueBoardError.unsupported("The saved Studio library has an unresolved validation error. Import preserves the existing data.")
        }
        return try HueSceneDocumentCodec.mergingLibrary(documents, into: savedStudioDocuments, contract: contract)
    }

    private func roomImport(_ imported: HueRoomLayout) throws -> (HueRoomLayout, HueRoomLayout, HueArea) {
        guard canEditRoomLayout, roomLayoutIssue == nil, let current = roomLayout, let area = selectedArea else {
            throw HueBoardError.unsupported("Select the matching room or zone on a connected Bridge before importing this layout.")
        }
        let known = try current.includingNewLights(from: area)
        return (known, try known.mergingPlacements(from: imported, in: area), area)
    }
}
