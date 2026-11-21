import CryptoKit
import Foundation
import HueBoardKit
import HueBoardNativeCore

struct HueSetupLayoutChoice: Identifiable, Equatable {
    let id: String
    let title: String
    let fixtureCount: Int
}

struct HueSetupDurableChanges: Equatable {
    var library: [HueSceneDocument]?
    var favorites: Set<String>?
    var layouts: [String: HueRoomLayout] = [:]
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
    fileprivate let layoutScopes: Set<String>
    fileprivate let presentFixtureIDs: [String: [String]]
    fileprivate let fingerprint: SetupImportTransaction.Fingerprint
}

@MainActor
extension AppModel {
    var availableSetupExportSections: Set<HueSetupSection> {
        var result: Set<HueSetupSection> = [.draft, .palette, .cues, .favorites, .safety]
        if studioLibraryIssue == nil { result.insert(.mixes) }
        if !availableSetupLayoutChoices.isEmpty { result.insert(.layout) }
        return result
    }

    private func setupScope(for area: HueArea) -> String? {
        guard isReady, let profile else { return nil }
        let key = ["hue-board.setup.room.v1", profile.bridgeID.lowercased(), area.kind.rawValue, area.id.rawValue]
        let bytes = Data(key.joined(separator: "\u{0}").utf8)
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    func setupArea(for scope: String, id: HueResourceID) -> HueArea? {
        let matching = areas.filter { $0.id == id }
        guard matching.count == 1, let area = matching.first, setupScope(for: area) == scope else { return nil }
        return area
    }

    var availableSetupLayoutChoices: [HueSetupLayoutChoice] {
        guard isReady, let profile,
              let saved = try? roomLayoutStore.savedAreaIDs(bridgeID: profile.bridgeID, areas: areas) else { return [] }
        return areas.compactMap { area in
            guard let scope = setupScope(for: area), setupArea(for: scope, id: area.id) != nil else { return nil }
            if selectedArea?.id == area.id {
                guard roomLayoutIssue == nil, roomLayout?.areaID == area.id else { return nil }
            } else if !saved.contains(area.id) { return nil }
            return HueSetupLayoutChoice(id: scope, title: area.name, fixtureCount: area.lights.count)
        }
    }

    func setupImportLayoutChoices(_ setup: HueSetupDocument) -> [HueSetupLayoutChoice] {
        setup.layouts.enumerated().map { offset, room in
            let target = setupArea(for: room.scope, id: room.layout.areaID)
            return .init(id: room.scope, title: target?.name ?? "Layout \(offset + 1)",
                         fixtureCount: room.layout.placements.count)
        }
    }

    private func localSetupLayout(for area: HueArea) throws -> HueRoomLayout {
        guard isReady, let profile else { throw HueBoardError.unsupported("Connect to the original Bridge.") }
        if selectedArea?.id == area.id {
            guard roomLayoutIssue == nil, let roomLayout, roomLayout.areaID == area.id,
                  roomLayoutScope == nil || roomLayoutScope == "\(profile.bridgeID)/\(area.id.rawValue)" else {
                throw HueBoardError.unsupported("The selected room’s layout is unavailable.")
            }
            return try roomLayout.includingNewLights(from: area)
        }
        return try roomLayoutStore.load(bridgeID: profile.bridgeID, area: area)
    }

    private var currentSetupDraft: HueStudioDraft {
        .init(settings: studioSceneSettings, sourceLookID: selectedPresetID, duration: liveDuration,
              cuesEnabled: isCueSequenceEnabled)
    }

    func exportSetup(sections: Set<HueSetupSection>, layoutScopes: Set<String>? = nil) throws -> HuePortableData {
        guard !sections.isEmpty, sections.isSubset(of: availableSetupExportSections) else {
            throw HueBoardError.unsupported("Choose one or more available setup sections.")
        }
        let cues = HueCueSequence(presetIDs: cueIDs, holdSeconds: cueHoldSeconds, order: cueOrder, seed: studioSettings.seed)
        var layouts: [HueSetupRoom] = []
        if sections.contains(.layout) {
            let current = selectedArea.flatMap(setupScope)
            let wanted = layoutScopes ?? Set([current].compactMap { $0 })
            guard !wanted.isEmpty, wanted.isSubset(of: Set(availableSetupLayoutChoices.map(\.id))) else {
                throw HueBoardError.unsupported("Choose at least one available room layout to export.")
            }
            for area in areas {
                if let scope = setupScope(for: area), wanted.contains(scope) {
                    layouts.append(.init(scope: scope, layout: try localSetupLayout(for: area)))
                }
            }
            layouts.sort { $0.scope < $1.scope }
        }
        let setup = HueSetupDocument(
            draft: sections.contains(.draft) ? currentSetupDraft : nil,
            palette: sections.contains(.palette) ? studioSettings.customColors : nil,
            cues: sections.contains(.cues) ? cues : nil,
            cuesEnabled: sections.contains(.cues) ? isCueSequenceEnabled : nil,
            mixes: sections.contains(.mixes) ? savedStudioDocuments : nil,
            favorites: sections.contains(.favorites) ? favoritePresetIDs.sorted() : nil,
            layouts: layouts,
            safety: sections.contains(.safety) ? .init(reduceLightMotion: safetySettings.reduceLightMotion,
                                                       maximumDynamicBrightness: safetySettings.maximumDynamicBrightness) : nil
        )
        return .setup(setup)
    }

    func reviewSetup(
        _ setup: HueSetupDocument, sections: Set<HueSetupSection>, layoutScopes: Set<String>? = nil
    ) throws -> HueSetupReview {
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
        var presentFixtureIDs: [String: [String]] = [:]
        var reviewedScopes = Set<String>()

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
        if sections.contains(.layout) {
            let available = Set(setup.layouts.map(\.scope))
            reviewedScopes = layoutScopes ?? (available.count == 1 ? available : [])
            guard !reviewedScopes.isEmpty, reviewedScopes.isSubset(of: available) else {
                throw HueBoardError.unsupported("Choose at least one room layout from this setup.")
            }
            for (index, room) in setup.layouts.enumerated() where reviewedScopes.contains(room.scope) {
                guard canEditRoomLayout, let area = setupArea(for: room.scope, id: room.layout.areaID) else {
                    lines.append("Layout \(index + 1) skipped. Its original Bridge and room are unavailable.")
                    continue
                }
                let current = try localSetupLayout(for: area)
                let present = Set(area.lights.map(\.id))
                presentFixtureIDs[room.scope] = present.map(\.rawValue).sorted()
                before.layouts[room.scope] = current
                let byID = Dictionary(uniqueKeysWithValues: current.placements.map { ($0.id, $0) })
                var matches: [HueFixturePlacement] = []
                var details: [String] = []
                for var placement in room.layout.placements {
                    guard present.contains(placement.id), let previous = byID[placement.id],
                          let light = area.lights.first(where: { $0.id == placement.id }) else {
                        details.append("\(area.name) · \(placement.id.rawValue): unavailable, skipped.")
                        continue
                    }
                    // A file cannot re-enlist a fixture excluded on the receiving installation.
                    if !previous.selected && placement.selected {
                        placement.selected = false
                        details.append("\(area.name) · \(light.name): remains excluded from Live.")
                    }
                    if previous.ceiling != placement.ceiling {
                        details.append("\(area.name) · \(light.name) brightness ceiling: \(previous.ceiling.formatted())% → \(placement.ceiling.formatted())%.")
                    }
                    var edits: [String] = []
                    if previous.x != placement.x || previous.y != placement.y { edits.append("position") }
                    if previous.phase != placement.phase { edits.append("phase") }
                    if previous.role != placement.role { edits.append("role") }
                    if previous.trim != placement.trim { edits.append("trim") }
                    if previous.selected != placement.selected { edits.append("exclude from Live") }
                    if !edits.isEmpty { details.append("\(area.name) · \(light.name): \(edits.joined(separator: ", ")).") }
                    matches.append(placement)
                }
                if !matches.isEmpty {
                    let imported = HueRoomLayout(areaID: area.id, placements: matches)
                    after.layouts[room.scope] = try current.mergingPlacements(from: imported, in: area)
                }
                let skipped = room.layout.placements.count - matches.count
                lines.append("\(area.name): \(matches.count) matching fixture placements, \(skipped) unavailable and skipped.")
                lines.append(contentsOf: details)
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
                     roomScope: sections.contains(.layout) ? selectedArea.flatMap(setupScope) : nil,
                     layoutScopes: reviewedScopes, presentFixtureIDs: presentFixtureIDs, fingerprint: fingerprint)
    }

    func applySetup(
        _ setup: HueSetupDocument, sections: Set<HueSetupSection>,
        layoutScopes: Set<String>? = nil, review: HueSetupReview
    ) async throws {
        try requireIdleTransfer()
        // The coordinator can still own a one-shot lease while the visible playback snapshot says idle.
        guard await playbackCoordinator.currentLease() == nil,
              try await persistence.isIdleForLocalImport() else {
            throw HueBoardError.unsupported("Finish playback and resolve recovery before importing a setup.")
        }
        // Main-actor code from revalidation to publication has no suspension point.
        let fresh = try reviewSetup(setup, sections: sections, layoutScopes: layoutScopes)
        guard fresh.canApply, fresh == review else {
            throw HueBoardError.unsupported("The setup or destination changed. Review the current changes before importing.")
        }
        try commitSetupStorage(fresh.after, expected: fresh.fingerprint)
        if let library = fresh.after.library { savedStudioDocuments = library }
        if let favorites = fresh.after.favorites { favoritePresetIDs = favorites }
        if let scope = selectedArea.flatMap(setupScope), let layout = fresh.after.layouts[scope] { roomLayout = layout }
        if let safety = fresh.after.safety { safetySettings = safety }
        if let draft = fresh.nextDraft {
            applyStudioSceneSettings(draft.settings)
            selectedPresetID = draft.sourceLookID
            liveDuration = draft.duration
            isCueSequenceEnabled = draft.cuesEnabled
        }
    }
}
