/// A successful read of both Entertainment inventories on a Hue Bridge.
public enum HueRoomDiscovery: Equatable, Sendable {
    case noSavedAreas
    case noMatchingPositions
    case matches([HueRoomArrangement], fixtureCount: Int)

    public init(
        configurations: [HueEntertainmentConfigurationResource],
        services: [HueEntertainmentServiceResource],
        in area: HueArea
    ) {
        guard !configurations.isEmpty else { self = .noSavedAreas; return }
        let options = HueRoomArrangement.matching(configurations: configurations, services: services, in: area)
        if options.isEmpty {
            self = .noMatchingPositions
        } else {
            self = .matches(options, fixtureCount: Set(area.lights.map(\.id)).count)
        }
    }

    public var arrangements: [HueRoomArrangement] {
        if case let .matches(options, _) = self { return options }
        return []
    }
}
