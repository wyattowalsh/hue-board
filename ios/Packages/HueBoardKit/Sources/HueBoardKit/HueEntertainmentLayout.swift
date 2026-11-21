import Foundation

/// Saved service positions from the Hue app's Entertainment configuration.
public struct HueEntertainmentConfigurationResource: Codable, Equatable, Sendable {
    struct Locations: Codable, Equatable, Sendable {
        let serviceLocations: [ServiceLocation]?

        enum CodingKeys: String, CodingKey {
            case serviceLocations = "service_locations"
        }
    }

    struct ServiceLocation: Codable, Equatable, Sendable {
        let service: HueResourceReference
        let positions: [HueEntertainmentPosition]?
        let position: HueEntertainmentPosition?

        var center: HueEntertainmentPosition? {
            if let positions, !positions.isEmpty {
                return HueEntertainmentPosition.center(of: positions)
            }
            return position.flatMap { HueEntertainmentPosition.center(of: [$0]) }
        }
    }

    public let id: HueResourceID
    let metadata: HueMetadataResource?
    let name: String?
    let locations: Locations?

    var displayName: String {
        let name = (metadata?.name ?? self.name)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.flatMap { $0.isEmpty ? nil : $0 } ?? "Unnamed Entertainment area"
    }
}

public struct HueEntertainmentServiceResource: Codable, Equatable, Sendable {
    public let id: HueResourceID
    let rendererReference: HueResourceReference?

    enum CodingKeys: String, CodingKey {
        case id
        case rendererReference = "renderer_reference"
    }
}

struct HueEntertainmentPosition: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let z: Double

    static func center(of positions: [Self]) -> Self? {
        guard (1...256).contains(positions.count), positions.allSatisfy({ position in
            [position.x, position.y, position.z].allSatisfy { (-1...1).contains($0) }
        }) else { return nil }
        let count = Double(positions.count)
        return .init(
            x: positions.reduce(0) { $0 + $1.x } / count,
            y: positions.reduce(0) { $0 + $1.y } / count,
            z: positions.reduce(0) { $0 + $1.z } / count
        )
    }
}

/// A saved Hue configuration projected onto the current Hue Board room or zone.
public struct HueRoomArrangement: Equatable, Identifiable, Sendable {
    public let id: HueResourceID
    public let name: String
    public let areaID: HueResourceID
    private let positions: [HueResourceID: HueEntertainmentPosition]

    public var matchedCount: Int { positions.count }

    public static func matching(
        configurations: [HueEntertainmentConfigurationResource],
        services: [HueEntertainmentServiceResource],
        in area: HueArea
    ) -> [Self] {
        let lightIDs = Set(area.lights.map(\.id))
        let servicesByID = Dictionary(grouping: services, by: \.id)
        let configurationCounts = Dictionary(grouping: configurations, by: \.id).mapValues(\.count)

        func resolveLight(from reference: HueResourceReference) -> HueResourceID? {
            switch reference.resourceType {
            case "light":
                return reference.resourceID
            case "entertainment":
                guard let candidates = servicesByID[reference.resourceID], candidates.count == 1,
                      let renderer = candidates.first?.rendererReference, renderer.resourceType == "light"
                else { return nil }
                return renderer.resourceID
            default:
                return nil
            }
        }

        return configurations.compactMap { configuration -> Self? in
            guard !configuration.id.rawValue.isEmpty, configurationCounts[configuration.id] == 1 else { return nil }
            var positions: [HueResourceID: HueEntertainmentPosition] = [:]
            var rejected = Set<HueResourceID>()
            for location in configuration.locations?.serviceLocations ?? [] {
                guard let lightID = resolveLight(from: location.service), lightIDs.contains(lightID) else { continue }
                guard positions[lightID] == nil, let center = location.center else {
                    rejected.insert(lightID)
                    continue
                }
                positions[lightID] = center
            }
            for lightID in rejected { positions.removeValue(forKey: lightID) }
            guard !positions.isEmpty else { return nil }
            return .init(id: configuration.id, name: configuration.displayName, areaID: area.id, positions: positions)
        }.sorted { left, right in
            if left.matchedCount != right.matchedCount { return left.matchedCount > right.matchedCount }
            let byName = left.name.localizedStandardCompare(right.name)
            if byName != .orderedSame { return byName == .orderedAscending }
            return left.id.rawValue < right.id.rawValue
        }
    }

    public func applying(to layout: HueRoomLayout, in area: HueArea) throws -> HueRoomLayout {
        let currentLightIDs = Set(area.lights.map(\.id))
        guard areaID == area.id, positions.keys.allSatisfy(currentLightIDs.contains) else {
            throw HueBoardError.invalidResponse("The room or its fixtures changed. Read the saved Hue arrangements again.")
        }
        var updated = try layout.includingNewLights(from: area)
        for index in updated.placements.indices {
            guard let position = positions[updated.placements[index].id] else { continue }
            // Top view: Hue X increases right and Hue Y points toward the top of the map.
            updated.placements[index].x = 0.5 + 0.40 * position.x
            updated.placements[index].y = 0.5 - 0.40 * position.y
        }
        try updated.validate(for: area)
        return updated
    }
}
