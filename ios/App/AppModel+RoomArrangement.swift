import Foundation
import HueBoardKit
import HueBoardNativeCore

struct RoomArrangementPreview: Identifiable {
    let scope: RoomDiscoveryScope
    let area: HueArea
    let arrangement: HueRoomArrangement
    let originalLayout: HueRoomLayout
    let proposedLayout: HueRoomLayout

    var id: HueResourceID { arrangement.id }
}

@MainActor
extension AppModel {
    var roomDiscoveryScope: RoomDiscoveryScope? {
        guard canEditRoomLayout, roomLayoutIssue == nil, roomLayout != nil, credential != nil,
              let profile, let area = selectedArea,
              roomLayoutScope == "\(profile.bridgeID)/\(area.id.rawValue)" else { return nil }
        return .init(bridgeID: profile.bridgeID, areaID: area.id,
                     fixtureIDs: Set(area.lights.map(\.id)), revision: roomDiscoveryRevision)
    }

    func fetchRoomArrangements(in scope: RoomDiscoveryScope) async throws -> HueRoomDiscovery {
        guard roomDiscoveryScope == scope, let profile, let credential, let area = selectedArea else {
            throw HueBoardError.unsupported("Select a room or zone on a connected, idle Bridge to read saved Hue layouts.")
        }
        let result = try await client.roomDiscovery(profile: profile, credential: credential, in: area)
        try Task.checkCancellation()
        guard roomDiscoveryScope == scope else { throw CancellationError() }
        return result
    }

    func previewRoomArrangement(_ arrangement: HueRoomArrangement, from scope: RoomDiscoveryScope) throws -> RoomArrangementPreview {
        guard roomDiscoveryScope == scope, let area = selectedArea, let layout = roomLayout else {
            throw HueBoardError.unsupported("The room changed. Read its layouts again.")
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
        roomDiscoveryScope == preview.scope && roomLayout == preview.originalLayout
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
