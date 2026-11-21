import Foundation
import HueBoardKit

public struct EmergencyOffResult: Sendable {
    public let areaID: HueResourceID
    public let accepted: Set<HueResourceID>
    public let unresolved: Set<HueResourceID>
}

public enum EmergencyOffOperation {
    public static func run(
        profile: BridgeProfile, credential: HueBridgeCredential, selectedArea: HueArea,
        inventory: [HueArea], client: any HueLightUpdateSending,
        coordinator: PlaybackCoordinator, persistence: AppPersistence,
        readSelectedArea: @Sendable () async throws -> HueArea?
    ) async throws -> EmergencyOffResult {
        // Revoke first, including when a later inventory or persistence read fails.
        _ = await coordinator.stopCurrent(reason: .user)
        let saved = try await persistence.loadRestoreJournal()
        let targetIDs: Set<HueResourceID>
        let scope: HueResourceID
        let eligible: [HueLight]
        if var journal = saved {
            guard journal.bridgeID == profile.bridgeID else {
                throw HueBoardError.unsupported("The saved baseline belongs to another Bridge. Reconnect it before using emergency off.")
            }
            targetIDs = journal.capturedLightIDs
            scope = journal.areaID
            var seen: Set<HueResourceID> = []
            eligible = inventory.flatMap(\.lights).filter {
                targetIDs.contains($0.id) && seen.insert($0.id).inserted && $0.capabilities.power && !$0.capabilities.streaming
            }
            if !eligible.isEmpty, journal.restoreAcceptedAt != nil {
                journal.restoreAcceptedAt = nil
                try await persistence.saveRestoreJournal(journal)
            }
        } else {
            guard let fresh = try await readSelectedArea(), fresh.id == selectedArea.id else {
                throw HueBoardError.missingResource("The selected area could not be refreshed before emergency off.")
            }
            targetIDs = Set(selectedArea.lights.map(\.id))
            scope = fresh.id
            eligible = fresh.lights.filter { targetIDs.contains($0.id) && $0.capabilities.power && !$0.capabilities.streaming }
            if !eligible.isEmpty {
                let journal = RestoreJournal(bridgeID: profile.bridgeID, area: fresh, lights: eligible)
                try await persistence.saveRestoreJournal(journal)
            }
        }
        let eligibleIDs = Set(eligible.map(\.id))
        guard !eligibleIDs.isEmpty else {
            throw HueBoardError.unsupported("No recoverable non-streaming lights are currently available for emergency off.")
        }
        let transport = DirectControlTransport(client: client, profile: profile, credential: credential,
                                              allowedLightIDs: eligibleIDs)
        let lease = try await coordinator.begin(
            .init(scope: .init(bridgeID: profile.bridgeID, areaID: scope),
                  transport: .directControl, presetID: "emergency-off"), using: transport
        )
        var accepted: Set<HueResourceID> = []
        for (index, id) in eligibleIDs.sorted(by: { $0.rawValue < $1.rawValue }).enumerated() {
            do {
                try await coordinator.submit(
                    .init(sequence: UInt64(index + 1), actions: [id: .init(on: .init(on: false))]), lease: lease
                )
                accepted.insert(id)
            } catch {
                // Leave the original snapshot available after any uncertain or rejected write.
                if !(await coordinator.isCurrent(lease)) { break }
            }
        }
        _ = await coordinator.stopCurrent(reason: .completed, matching: lease)
        guard !accepted.isEmpty else {
            throw HueBoardError.network("No emergency-off command was accepted. The saved baseline remains available.")
        }
        return .init(areaID: scope, accepted: accepted, unresolved: targetIDs.subtracting(accepted))
    }
}
