import Foundation

public struct HueEventContainer: Decodable, Equatable, Sendable {
    public let creationTime: String?
    public let id: String
    public let type: String
    public let data: [HueEventResource]

    enum CodingKeys: String, CodingKey {
        case creationTime = "creationtime"
        case id, type, data
    }
}

public struct HueEventResource: Decodable, Equatable, Sendable {
    public let id: HueResourceID
    public let type: String
    public let on: HueLightResource.OnState?
    public let dimming: HueLightResource.DimmingState?
    public let color: HueLightResource.ColorState?
    public let colorTemperature: HueLightResource.TemperatureState?
    public let dynamics: HueLightResource.DynamicsState?
    public let mode: String?

    enum CodingKeys: String, CodingKey {
        case id, type, on, dimming, color, dynamics, mode
        case colorTemperature = "color_temperature"
    }
}

public struct HueEventBatch: Equatable, Sendable {
    public let containers: [HueEventContainer]

    public init(containers: [HueEventContainer]) {
        self.containers = containers
    }

    public var resources: [HueEventResource] {
        containers.flatMap(\.data)
    }

    public var requiresInventoryRefresh: Bool {
        containers.contains { $0.type == "add" || $0.type == "delete" }
            || resources.contains {
                ["room", "zone", "device", "grouped_light"].contains($0.type)
            }
    }
}

public extension HueLight {
    func applying(_ event: HueEventResource) -> HueLight {
        guard event.type == "light", event.id == id else { return self }

        let updatedTemperature: Int?
        if let temperature = event.colorTemperature {
            updatedTemperature = temperature.valid == false
                ? nil
                : temperature.mirek ?? colorTemperatureMirek
        } else {
            updatedTemperature = colorTemperatureMirek
        }

        let updatedCapabilities = HueLightCapabilities(
            power: capabilities.power,
            dimming: capabilities.dimming,
            color: capabilities.color,
            colorTemperature: capabilities.colorTemperature,
            dynamicPalette: capabilities.dynamicPalette,
            gradientPoints: capabilities.gradientPoints,
            effects: capabilities.effects,
            streaming: event.mode.map { $0 == "streaming" } ?? capabilities.streaming
        )

        return HueLight(
            id: id,
            ownerID: ownerID,
            name: name,
            isOn: event.on?.on ?? isOn,
            brightness: event.dimming?.brightness ?? brightness,
            color: event.color?.xy ?? color,
            colorTemperatureMirek: updatedTemperature,
            dynamicStatus: event.dynamics?.status ?? dynamicStatus,
            gamut: event.color?.gamut ?? gamut,
            capabilities: updatedCapabilities,
            outputLimit: outputLimit
        )
    }
}
