import Foundation

public enum HueCueOrder: String, Codable, CaseIterable, Sendable {
    case forward
    case shuffle
}

public struct HueCueAtTime: Equatable, Sendable {
    public let presetID: String
    public let index: Int
    public let position: Int
    public let count: Int
    public let cycle: Int
    public let slotElapsed: TimeInterval
    public let remaining: TimeInterval
}

/// Immutable, deterministic cue schedule. The caller measures monotonic
/// elapsed session time; missed cues are skipped, never replayed as catch-up writes.
public struct HueCueSequence: Codable, Equatable, Sendable {
    public let presetIDs: [String]
    public let holdSeconds: Double
    public let order: HueCueOrder
    public let seed: Int

    public init(
        presetIDs: [String],
        holdSeconds: Double,
        order: HueCueOrder,
        seed: Int
    ) {
        self.presetIDs = presetIDs
        self.holdSeconds = holdSeconds
        self.order = order
        self.seed = seed
    }

    public func validate(contract: HueBoardContract) throws {
        let validIDs = Set(contract.presets.map(\.id))
        guard (1...12).contains(presetIDs.count),
              presetIDs.allSatisfy(validIDs.contains),
              holdSeconds.isFinite, (30...600).contains(holdSeconds),
              (order == .forward || Set(presetIDs).count == presetIDs.count)
        else {
            throw HueBoardError.unsupported(
                "Choose 1–12 known cues and a hold duration of 30–600 seconds."
            )
        }
    }

    public func cue(at elapsed: TimeInterval) throws -> HueCueAtTime {
        guard !presetIDs.isEmpty, holdSeconds.isFinite, holdSeconds > 0,
              elapsed.isFinite, elapsed >= 0, elapsed <= 24 * 60 * 60 else {
            throw HueBoardError.unsupported("The cue timeline is invalid.")
        }
        let slot = Int(elapsed / holdSeconds)
        let cycle = slot / presetIDs.count
        let offset = slot % presetIDs.count
        let index: Int
        switch order {
        case .forward:
            index = offset
        case .shuffle:
            var last: Int?
            var chosen = 0
            for iteration in 0...cycle {
                let indexes = shuffledIndexes(cycle: iteration, after: last)
                chosen = indexes[offset]
                last = indexes.last
            }
            index = chosen
        }

        let slotElapsed = elapsed - Double(slot) * holdSeconds
        return .init(
            presetID: presetIDs[index],
            index: index,
            position: offset,
            count: presetIDs.count,
            cycle: cycle,
            slotElapsed: slotElapsed,
            remaining: max(0, holdSeconds - slotElapsed)
        )
    }

    private func shuffledIndexes(cycle: Int, after previousLast: Int?) -> [Int] {
        var values = Array(presetIDs.indices)
        var state = UInt64(bitPattern: Int64(seed))
            ^ (UInt64(cycle) &* 0x9E3779B97F4A7C15)
        if values.count > 1 {
            for index in stride(from: values.count - 1, through: 1, by: -1) {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                values.swapAt(index, Int(state % UInt64(index + 1)))
            }
            if let previousLast, values[0] == previousLast {
                values.swapAt(0, 1)
            }
        }
        return values
    }

    public func settings(
        at elapsed: TimeInterval,
        contract: HueBoardContract,
        base: HueEngineSettings
    ) throws -> (settings: HueEngineSettings, cue: HueCueAtTime) {
        try validate(contract: contract)
        let point = try cue(at: elapsed)
        guard let preset = contract.preset(id: point.presetID) else {
            throw HueBoardError.missingResource("The scheduled cue has been removed.")
        }
        var settings = HueEngineSettings.from(preset: preset, brightness: base.brightness)
        settings.seed = base.seed
        settings.topology = base.topology
        settings.reverse = base.reverse
        settings.gradient = base.gradient
        settings.customColors = base.customColors
        return (settings, point)
    }
}
