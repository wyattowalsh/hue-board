import Foundation
import HueBoardKit

public extension RestoreJournal {
    var capturedLightIDs: Set<HueResourceID> {
        Set(snapshots.map(\.lightID))
    }

    func snapshotsEligibleForRestore(in areas: [HueArea]) -> [HueLightSnapshot] {
        let lights = Self.lightsByID(in: areas)
        return snapshots.filter { snapshot in
            guard let light = lights[snapshot.lightID] else { return false }
            return snapshot.canRestore(to: light)
        }
    }

    func snapshotsAwaitingRestoreReadback(in areas: [HueArea]) -> [HueLightSnapshot] {
        let lights = Self.lightsByID(in: areas)
        return snapshots.filter { snapshot in
            guard let light = lights[snapshot.lightID] else { return true }
            return !snapshot.matchesRestoreReadback(light)
        }
    }

    private static func lightsByID(in areas: [HueArea]) -> [HueResourceID: HueLight] {
        Dictionary(
            areas.lazy.flatMap(\.lights).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
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
        if !missing.isEmpty { restoreAcceptedAt = nil }
        return missing.count
    }
}
