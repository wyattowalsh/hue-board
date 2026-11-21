import CryptoKit
import Foundation
import HueBoardKit
import HueBoardNativeCore

struct HueSetupDurableChanges: Equatable {
    var library: [HueSceneDocument]?
    var favorites: Set<String>?
    var layout: HueRoomLayout?
    var safety: PhysicalLightSafetySettings?
}

struct HueSetupReview: Equatable {
    let lines: [String]
    let canApply: Bool
    fileprivate let source: HueSetupDocument
    fileprivate let sections: Set<HueSetupSection>
    fileprivate let before: HueSetupDurableChanges
    fileprivate let after: HueSetupDurableChanges
    fileprivate let currentDraft: HueStudioDraft?
    fileprivate let nextDraft: HueStudioDraft?
    fileprivate let roomScope: String?
    fileprivate let presentFixtureIDs: [String]
    fileprivate let fingerprint: SetupImportTransaction.Fingerprint
}

@MainActor
extension AppModel {
    var availableSetupExportSections: Set<HueSetupSection> {
        var result: Set<HueSetupSection> = [.draft, .palette, .cues, .favorites, .safety]
        if studioLibraryIssue == nil { result.insert(.mixes) }
        if roomLayoutIssue == nil, roomLayout != nil, setupRoomScope != nil { result.insert(.layout) }
        return result
    }

    private var setupRoomScope: String? {
        guard isReady, let profile, let area = selectedArea, area.id == roomLayout?.areaID else { return nil }
        let key = ["hue-board.setup.room.v1", profile.bridgeID.lowercased(), area.kind.rawValue, area.id.rawValue]
        let bytes = Data(key.joined(separator: "\u{0}").utf8)
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private var currentSetupDraft: HueStudioDraft {
        .init(settings: studioSceneSettings, sourceLookID: selectedPresetID, duration: liveDuration,
              cuesEnabled: isCueSequenceEnabled)
    }

    func exportSetup(sections: Set<HueSetupSection>) throws -> HuePortableData {
        guard !sections.isEmpty, sections.isSubset(of: availableSetupExportSections) else {
            throw HueBoardError.unsupported("Choose one or more available setup sections.")
        }
        let cues = HueCueSequence(presetIDs: cueIDs, holdSeconds: cueHoldSeconds, order: cueOrder, seed: studioSettings.seed)
        var layout: HueSetupRoom?
        if sections.contains(.layout), let scope = setupRoomScope, let roomLayout {
            layout = .init(scope: scope, layout: roomLayout)
        }
        let setup = HueSetupDocument(
            draft: sections.contains(.draft) ? currentSetupDraft : nil,
            palette: sections.contains(.palette) ? studioSettings.customColors : nil,
            cues: sections.contains(.cues) ? cues : nil,
            cuesEnabled: sections.contains(.cues) ? isCueSequenceEnabled : nil,
            mixes: sections.contains(.mixes) ? savedStudioDocuments : nil,
            favorites: sections.contains(.favorites) ? favoritePresetIDs.sorted() : nil,
            layout: layout,
            safety: sections.contains(.safety) ? .init(reduceLightMotion: safetySettings.reduceLightMotion,
                                                       maximumDynamicBrightness: safetySettings.maximumDynamicBrightness) : nil
        )
        return .setup(setup)
    }

    func reviewSetup(_ setup: HueSetupDocument, sections: Set<HueSetupSection>) throws -> HueSetupReview {
        try requireIdleTransfer()
        guard sections.isSubset(of: setup.availableSections) else {
            throw HueBoardError.invalidResponse("A selected section is missing from this setup.")
        }
        // This also enforces document size and validates in-memory callers that bypass the Files picker.
        _ = try HuePortableDataCodec.encode(.setup(setup), contract: contract)
        var lines: [String] = []
        var blocked = false
        var before = HueSetupDurableChanges()
        var after = HueSetupDurableChanges()
        var currentDraft: HueStudioDraft?
        var nextDraft: HueStudioDraft?
        var presentFixtureIDs: [String] = []

        if !sections.isDisjoint(with: [.draft, .palette, .cues]) {
            let current = currentSetupDraft
            let next = setup.applyingStudioSections(sections, to: current)
            currentDraft = current
            nextDraft = next
            let fields = [HueSetupSection.draft, .palette, .cues].filter(sections.contains).map(\.title)
            lines.append("\(fields.joined(separator: ", ")) will load into Studio. Save as a mix to keep this session’s draft.")
            if current.settings.seed != next.settings.seed {
                lines.append("The random seed shared by the engine and cues changes from \(current.settings.seed) to \(next.settings.seed).")
            }
        }
        if sections.contains(.mixes), let mixes = setup.mixes {
            before.library = savedStudioDocuments
            do {
                after.library = try mergedLibrary(mixes)
                let added = (after.library?.count ?? 0) - savedStudioDocuments.count
                lines.append("Saved mixes: \(added) to add, \(mixes.count - added) already present.")
            } catch {
                blocked = true
                lines.append(error.localizedDescription)
                for mix in mixes {
                    if let existing = savedStudioDocuments.first(where: { $0.documentId == mix.documentId }), existing != mix {
                        lines.append("Mix ID conflict: “\(mix.name)” in the file and “\(existing.name)” in this library.")
                    }
                }
                lines.append("Deselect Saved mixes to import the other sections.")
            }
        }
        if sections.contains(.favorites), let favorites = setup.favorites {
            before.favorites = favoritePresetIDs
            after.favorites = Set(favorites)
            let new = Set(favorites)
            lines.append("Scene favorites: add \(new.subtracting(favoritePresetIDs).count), remove \(favoritePresetIDs.subtracting(new).count).")
        }
        if sections.contains(.layout), let room = setup.layout {
            if room.scope == setupRoomScope, let area = selectedArea, let current = roomLayout, roomLayoutIssue == nil,
               room.layout.areaID == area.id, canEditRoomLayout {
                let present = Set(area.lights.map(\.id))
                presentFixtureIDs = present.map(\.rawValue).sorted()
                let matches = room.layout.placements.filter { present.contains($0.id) }
                let skipped = room.layout.placements.count - matches.count
                let expanded = try current.includingNewLights(from: area)
                before.layout = expanded
                if !matches.isEmpty {
                    let matched = HueRoomLayout(areaID: area.id, placements: matches)
                    after.layout = try expanded.mergingPlacements(from: matched, in: area)
                }
                lines.append("\(area.name): \(matches.count) matching fixture placements, \(skipped) unavailable and skipped.")
                for placement in matches {
                    if let previous = expanded.placements.first(where: { $0.id == placement.id }),
                       previous.ceiling != placement.ceiling,
                       let light = area.lights.first(where: { $0.id == placement.id }) {
                        lines.append("\(light.name) brightness ceiling: \(previous.ceiling.formatted())% → \(placement.ceiling.formatted())%.")
                    }
                }
            } else {
                lines.append("Room layout skipped. Connect to the original Bridge and select its matching room or zone.")
            }
        }
        if sections.contains(.safety), let safety = setup.safety {
            before.safety = safetySettings
            after.safety = safety.applying(to: safetySettings)
            lines.append("Maximum dynamic brightness: \(safetySettings.maximumDynamicBrightness.formatted())% → \(safety.maximumDynamicBrightness.formatted())%.")
            let current = safetySettings.reduceLightMotion ? "on" : "off"
            let next = safety.reduceLightMotion ? "on" : "off"
            lines.append("Reduce Light Motion: \(current) → \(next). Warning consent stays on this device.")
        }
        let fingerprint = try setupStorageFingerprint(for: after)
        return .init(lines: lines, canApply: !blocked && (nextDraft != nil || after != .init()),
                     source: setup, sections: sections, before: before, after: after,
                     currentDraft: currentDraft, nextDraft: nextDraft,
                     roomScope: sections.contains(.layout) ? setupRoomScope : nil,
                     presentFixtureIDs: presentFixtureIDs, fingerprint: fingerprint)
    }

    func applySetup(_ setup: HueSetupDocument, sections: Set<HueSetupSection>, review: HueSetupReview) async throws {
        try requireIdleTransfer()
        // The coordinator can still own a one-shot lease while the visible playback snapshot says idle.
        guard await playbackCoordinator.currentLease() == nil,
              try await persistence.isIdleForLocalImport() else {
            throw HueBoardError.unsupported("Finish playback and resolve recovery before importing a setup.")
        }
        // Main-actor code from revalidation to publication has no suspension point.
        let fresh = try reviewSetup(setup, sections: sections)
        guard fresh.canApply, fresh == review else {
            throw HueBoardError.unsupported("The setup or destination changed. Review the current changes before importing.")
        }
        try commitSetupStorage(fresh.after, expected: fresh.fingerprint)
        if let library = fresh.after.library { savedStudioDocuments = library }
        if let favorites = fresh.after.favorites { favoritePresetIDs = favorites }
        if let layout = fresh.after.layout { roomLayout = layout }
        if let safety = fresh.after.safety { safetySettings = safety }
        if let draft = fresh.nextDraft {
            applyStudioSceneSettings(draft.settings)
            selectedPresetID = draft.sourceLookID
            liveDuration = draft.duration
            isCueSequenceEnabled = draft.cuesEnabled
        }
    }
}
