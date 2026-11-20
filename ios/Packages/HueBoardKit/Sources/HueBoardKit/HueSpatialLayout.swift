import Foundation

public enum HueFixtureRole: String, Codable, CaseIterable, Sendable {
    case wash
    case accent
    case task
    case anchor

    public var title: String {
        switch self {
        case .wash: "Architectural wash"
        case .accent: "Moving accent"
        case .task: "Steady task light"
        case .anchor: "Steady background"
        }
    }

    public var isStatic: Bool { self == .task || self == .anchor }
}

/// A local-only spatial plan for one Hue area. It is deliberately separate
/// from portable HueSceneDocument files and contains no credentials.
public struct HueFixturePlacement: Codable, Equatable, Identifiable, Sendable {
    public let id: HueResourceID
    public var selected: Bool
    public var x: Double
    public var y: Double
    public var phase: Double
    public var trim: Double
    public var ceiling: Double
    public var role: HueFixtureRole

    public init(
        id: HueResourceID,
        selected: Bool,
        x: Double, y: Double, phase: Double,
        trim: Double = 1, ceiling: Double = 100, role: HueFixtureRole = .wash
    ) {
        self.id = id
        self.selected = selected
        self.x = x
        self.y = y
        self.phase = phase
        self.trim = trim
        self.ceiling = ceiling
        self.role = role
    }

    public func validate() throws {
        guard x.isFinite, y.isFinite, phase.isFinite,
              trim.isFinite, ceiling.isFinite,
              (0...1).contains(x), (0...1).contains(y),
              (0...1).contains(phase),
              (0.1...1).contains(trim),
              (5...100).contains(ceiling)
        else {
            throw HueBoardError.invalidResponse("Saved fixture placement is outside its safety bounds.")
        }
    }

    public func brightness(for requested: Double, light: HueLight) -> Double? {
        guard selected, requested.isFinite, light.capabilities.dimming,
              light.minimumBrightness <= light.outputLimit else { return nil }
        let maximum = min(ceiling, light.outputLimit)
        guard maximum >= light.minimumBrightness else { return nil }
        return min(max(requested * trim, light.minimumBrightness), maximum)
    }
}

public struct HueRoomLayout: Codable, Equatable, Sendable {
    public let areaID: HueResourceID
    public var placements: [HueFixturePlacement]

    public init(areaID: HueResourceID, placements: [HueFixturePlacement]) {
        self.areaID = areaID
        self.placements = placements
    }

    public func validate(for area: HueArea) throws {
        guard area.id == areaID, placements.count <= 100 else {
            throw HueBoardError.invalidResponse("The saved layout does not belong to this area or is too large.")
        }
        var seen = Set<HueResourceID>()
        for placement in placements {
            guard !placement.id.rawValue.isEmpty, seen.insert(placement.id).inserted else {
                throw HueBoardError.invalidResponse("Duplicate or invalid fixture IDs in the saved layout.")
            }
            try placement.validate()
        }
    }

    public static func startingLayout(for area: HueArea) -> Self {
        let count = max(1, area.lights.count)
        return .init(areaID: area.id, placements: area.lights.enumerated().map { offset, light in
            let phase = Double(offset) / Double(count)
            let angle = phase * 2 * Double.pi
            return HueFixturePlacement(
                id: light.id,
                selected: light.capabilities.color && light.capabilities.dimming
                    && !light.capabilities.streaming,
                x: 0.5 + 0.40 * sin(angle),
                y: 0.5 - 0.40 * cos(angle),
                phase: phase
            )
        })
    }

    /// Old placements are retained, even when a light is temporarily absent.
    /// Newly discovered lights start deselected to avoid silent scope expansion.
    public func includingNewLights(from area: HueArea) throws -> Self {
        try validate(for: area)
        var result = self
        var seen = Set(placements.map(\.id))
        for light in area.lights where seen.insert(light.id).inserted {
            result.placements.append(.init(
                id: light.id, selected: false, x: 0.5, y: 0.5, phase: 0
            ))
        }
        try result.validate(for: area)
        return result
    }

    public func selectedEntries(in area: HueArea) -> [(HueLight, HueFixturePlacement)] {
        let byID = Dictionary(uniqueKeysWithValues: area.lights.map { ($0.id, $0) })
        return placements.compactMap { placement in
            guard placement.selected,
                  let light = byID[placement.id],
                  light.capabilities.color, light.capabilities.dimming,
                  !light.capabilities.streaming,
                  placement.brightness(for: light.brightness ?? 50, light: light) != nil
            else { return nil }
            return (light, placement)
        }
    }
}
