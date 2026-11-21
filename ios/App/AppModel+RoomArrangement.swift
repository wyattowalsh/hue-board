import Foundation
import HueBoardKit
import HueBoardNativeCore

struct RoomArrangementPreview: Identifiable {
    let scope: String
    let area: HueArea
    let arrangement: HueRoomArrangement
    let originalLayout: HueRoomLayout
    let proposedLayout: HueRoomLayout

    var id: HueResourceID { arrangement.id }
}

@MainActor
extension AppModel {
    var canImportRoomArrangement: Bool { editableArrangementScope != nil }

    private var editableArrangementScope: String? {
        guard canEditRoomLayout, roomLayoutIssue == nil, roomLayout != nil,
              let profile, let area = selectedArea,
              roomLayoutScope == "\(profile.bridgeID)/\(area.id.rawValue)" else { return nil }
        return roomLayoutScope
    }

    func fetchRoomArrangements() async throws -> [HueRoomArrangement] {
        guard let scope = editableArrangementScope, let profile, let credential, let area = selectedArea else {
            throw HueBoardError.unsupported("Select a room or zone on a connected, idle Bridge before reading saved Hue layouts.")
        }
        let arrangements = try await client.roomArrangements(profile: profile, credential: credential, in: area)
        try Task.checkCancellation()
        guard editableArrangementScope == scope else {
            throw HueBoardError.unsupported("The room or playback state changed. Read its saved Hue layouts again.")
        }
        return arrangements
    }

    func previewRoomArrangement(_ arrangement: HueRoomArrangement) throws -> RoomArrangementPreview {
        guard let scope = editableArrangementScope, let area = selectedArea, let layout = roomLayout else {
            throw HueBoardError.unsupported("A room layout preview requires a connected, idle Bridge and a valid local layout.")
        }
        return RoomArrangementPreview(
            scope: scope,
            area: area,
            arrangement: arrangement,
            originalLayout: layout,
            proposedLayout: try arrangement.applying(to: layout, in: area)
        )
    }

    func canSaveRoomArrangement(_ preview: RoomArrangementPreview) -> Bool {
        editableArrangementScope == preview.scope && roomLayout == preview.originalLayout
    }

    func saveRoomArrangement(_ preview: RoomArrangementPreview) throws {
        guard canSaveRoomArrangement(preview), let profile, let area = selectedArea, let layout = roomLayout else {
            throw HueBoardError.unsupported("The room, its local layout, or playback changed. Preview the saved layout again.")
        }
        let verified = try preview.arrangement.applying(to: layout, in: area)
        guard verified == preview.proposedLayout else {
            throw HueBoardError.invalidResponse("The matching fixtures changed. Read and preview the saved layout again.")
        }
        try roomLayoutStore.save(verified, bridgeID: profile.bridgeID, area: area)
        roomLayout = verified
        note = "Saved the Hue layout positions to this room."
    }
}
