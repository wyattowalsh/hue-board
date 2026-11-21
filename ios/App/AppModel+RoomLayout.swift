import Foundation
import HueBoardKit

@MainActor
extension AppModel {
    /// A read-only load; a damaged saved layout is never replaced automatically.
    func loadCurrentRoomLayout() {
        roomDiscoveryRevision &+= 1
        guard let profile, let area = selectedArea else {
            roomLayout = nil
            roomLayoutScope = nil
            focusedFixtureID = nil
            return
        }
        let scope = "\(profile.bridgeID)/\(area.id.rawValue)"
        do {
            let value: HueRoomLayout
            if roomLayoutScope == scope, let roomLayout {
                value = try roomLayout.includingNewLights(from: area)
            } else {
                value = try roomLayoutStore.load(bridgeID: profile.bridgeID, area: area)
            }
            roomLayout = value
            roomLayoutScope = scope
            roomLayoutIssue = nil
            if !area.lights.contains(where: { $0.id == focusedFixtureID }) {
                focusedFixtureID = area.lights.first?.id
            }
        } catch {
            roomLayout = nil
            roomLayoutScope = scope
            roomLayoutIssue = "Saved room layout could not be verified: \(error.localizedDescription)"
        }
    }

    func updateRoomFixture(
        _ id: HueResourceID,
        change: (inout HueFixturePlacement) -> Void
    ) {
        guard canEditRoomLayout, roomLayoutIssue == nil, let profile,
              let area = selectedArea, var updated = roomLayout,
              let offset = updated.placements.firstIndex(where: { $0.id == id }),
              area.lights.contains(where: { $0.id == id })
        else {
            errorMessage = "Room placement edits require a ready, idle Bridge and a valid layout."
            return
        }

        change(&updated.placements[offset])
        do {
            try updated.validate(for: area)
            try roomLayoutStore.save(updated, bridgeID: profile.bridgeID, area: area)
            roomLayout = updated
        } catch {
            errorMessage = "The room edit was not saved: \(error.localizedDescription)"
        }
    }

    func resetRoomLayoutToRing() {
        guard canEditRoomLayout, roomLayoutIssue == nil,
              let area = selectedArea, let profile else {
            errorMessage = "The room layout cannot be reset during playback or recovery."
            return
        }
        let reset = HueRoomLayout.startingLayout(for: area)
        do {
            try roomLayoutStore.save(reset, bridgeID: profile.bridgeID, area: area)
            roomLayout = reset
            focusedFixtureID = area.lights.first?.id
            note = "Room positions were reset locally. No lights were changed."
        } catch {
            errorMessage = "Could not save the new room layout: \(error.localizedDescription)"
        }
    }
}

struct RoomSweepPreview: Identifiable {
    let id = UUID()
    let scope: RoomDiscoveryScope
    let original: HueRoomLayout
    let proposal: HueSweepProposal
    let area: HueArea
}

@MainActor
extension AppModel {
    func previewRoomSweep() throws -> RoomSweepPreview {
        guard let scope = roomDiscoveryScope, let layout = roomLayout, let area = selectedArea else {
            throw HueBoardError.unsupported("Choose a room on an idle, connected Bridge to preview a sweep.")
        }
        return .init(scope: scope, original: layout,
                     proposal: HueSweepProposal(layout: layout, in: area, brightnessLimit: effectiveDynamicBrightness),
                     area: area)
    }

    func canSaveRoomSweep(_ preview: RoomSweepPreview) -> Bool {
        guard preview.scope == roomDiscoveryScope, let area = selectedArea, let layout = roomLayout,
              layout == preview.original, !preview.proposal.changes.isEmpty else { return false }
        return preview.proposal == HueSweepProposal(layout: layout, in: area, brightnessLimit: effectiveDynamicBrightness)
    }

    func saveRoomSweep(_ preview: RoomSweepPreview) throws {
        guard canSaveRoomSweep(preview), let area = selectedArea, let profile else {
            throw HueBoardError.unsupported("The room or its moving fixtures changed. Preview the sweep again.")
        }
        try roomLayoutStore.save(preview.proposal.layout, bridgeID: profile.bridgeID, area: area)
        roomLayout = preview.proposal.layout
        note = "Saved sweep phases for this room."
    }
}
