import Foundation
import HueBoardKit

public extension RestoreJournal {
    var capturedLightIDs: Set<HueResourceID> {
        Set(snapshots.map(\.lightID))
    }

    /// Extends an existing restore point before a later playback action addresses newly eligible lights.
    /// Existing snapshots are immutable baselines and are never replaced with post-playback state.
    @discardableResult
    mutating func captureMissing(
        from area: HueArea,
        touchedIDs: Set<HueResourceID>,
        capturedAt: Date = Date()
    ) throws -> Int {
        guard area.id == areaID else {
            throw HueBoardError.unsupported(
                "Restore the previous area before capturing another playback baseline."
            )
        }

        let existing = capturedLightIDs
        let missing = area.lights.filter {
            touchedIDs.contains($0.id) && !existing.contains($0.id)
        }
        snapshots.append(
            contentsOf: missing.map { HueLightSnapshot(light: $0, capturedAt: capturedAt) }
        )
        return missing.count
    }
}
