import HueBoardKit

enum RoomDiscoveryReader {
    static func read(
        in area: HueArea,
        configurations: @Sendable () async throws -> [HueEntertainmentConfigurationResource],
        services: @Sendable () async throws -> [HueEntertainmentServiceResource]
    ) async throws -> HueRoomDiscovery {
        try Task.checkCancellation()
        async let saved = configurations()
        async let renderers = services()
        let inventories = try await (saved, renderers)
        try Task.checkCancellation()
        return HueRoomDiscovery(configurations: inventories.0, services: inventories.1, in: area)
    }
}
