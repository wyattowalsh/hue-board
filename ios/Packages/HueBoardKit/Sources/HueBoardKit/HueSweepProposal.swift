/// A local choreography proposal. Positions and output settings are preserved.
public struct HueSweepProposal: Equatable, Sendable {
    public struct Change: Equatable, Identifiable, Sendable {
        public let id: HueResourceID
        public let previous: Double
        public let phase: Double
    }

    public let eligibleIDs: Set<HueResourceID>
    public let distinctPositionCount: Int
    public let changes: [Change]
    public let layout: HueRoomLayout

    public init(layout: HueRoomLayout, in area: HueArea, brightnessLimit: Double) {
        let entries = layout.selectedEntries(in: area, brightnessLimit: brightnessLimit)
            .map { $0.1 }.filter { !$0.role.isStatic }
        eligibleIDs = Set(entries.map(\.id))
        let horizontal = Set(entries.map(\.x)).sorted()
        distinctPositionCount = horizontal.count
        guard horizontal.count > 1 else {
            self.layout = layout
            changes = []
            return
        }
        let phases = Dictionary(uniqueKeysWithValues: horizontal.enumerated().map { index, x in
            (x, Double(index) / Double(horizontal.count))
        })
        var updated = layout
        var edits: [Change] = []
        for index in updated.placements.indices {
            let placement = updated.placements[index]
            guard eligibleIDs.contains(placement.id), let phase = phases[placement.x],
                  placement.phase != phase else { continue }
            edits.append(.init(id: placement.id, previous: placement.phase, phase: phase))
            updated.placements[index].phase = phase
        }
        changes = edits
        self.layout = updated
    }
}
