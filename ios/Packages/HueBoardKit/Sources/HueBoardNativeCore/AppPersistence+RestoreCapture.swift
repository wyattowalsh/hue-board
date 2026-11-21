import Foundation
import HueBoardKit

public extension AppPersistence {
    /// Read, extend and persist inside one actor turn so overlapping intentions
    /// cannot overwrite an original snapshot captured by another operation.
    func captureRestoreBaseline(
        bridgeID: String, area: HueArea, touchedIDs: Set<HueResourceID>
    ) throws -> RestoreJournal {
        let touched = area.lights.filter { touchedIDs.contains($0.id) }
        guard !touched.isEmpty else { throw HueBoardError.unsupported("No compatible lights are selected.") }
        if var existing = try loadRestoreJournal() {
            guard existing.bridgeID == bridgeID, existing.areaID == area.id else {
                throw HueBoardError.unsupported("Restore the previous area before starting new playback.")
            }
            if try existing.captureMissing(from: area, touchedIDs: touchedIDs) > 0 {
                try saveRestoreJournal(existing)
            }
            return existing
        }
        let journal = RestoreJournal(bridgeID: bridgeID, area: area, lights: touched)
        try saveRestoreJournal(journal)
        return journal
    }

    /// A suspended read or network operation must never replace a newer baseline.
    @discardableResult
    func replaceRestoreJournal(_ next: RestoreJournal?, matching expected: RestoreJournal?) throws -> Bool {
        guard try loadRestoreJournal() == expected else { return false }
        try saveRestoreJournal(next)
        return true
    }
}
