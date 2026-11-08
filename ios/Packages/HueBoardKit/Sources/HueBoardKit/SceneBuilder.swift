import Foundation

public struct HueOnAction: Codable, Equatable, Sendable {
    public let on: Bool
    public init(on: Bool) { self.on = on }
}

public struct HueDimmingAction: Codable, Equatable, Sendable {
    public let brightness: Double
    public init(brightness: Double) { self.brightness = brightness }
}

public struct HueColorAction: Codable, Equatable, Sendable {
    public let xy: HueXY
    public init(xy: HueXY) { self.xy = xy }
}

public struct HueDynamicsAction: Codable, Equatable, Sendable {
    public let duration: Int
    public init(duration: Int) { self.duration = duration }
}

public struct HueColorTemperatureAction: Codable, Equatable, Sendable {
    public let mirek: Int
    public init(mirek: Int) { self.mirek = mirek }
}

public struct HueLightAction: Codable, Equatable, Sendable {
    public let on: HueOnAction?
    public let dimming: HueDimmingAction?
    public let color: HueColorAction?
    public let colorTemperature: HueColorTemperatureAction?
    public let dynamics: HueDynamicsAction?

    public init(
        on: HueOnAction? = nil,
        dimming: HueDimmingAction? = nil,
        color: HueColorAction? = nil,
        colorTemperature: HueColorTemperatureAction? = nil,
        dynamics: HueDynamicsAction? = nil
    ) {
        self.on = on
        self.dimming = dimming
        self.color = color
        self.colorTemperature = colorTemperature
        self.dynamics = dynamics
    }

    enum CodingKeys: String, CodingKey {
        case on, dimming, color, dynamics
        case colorTemperature = "color_temperature"
    }
}

public struct HueSceneAction: Codable, Equatable, Sendable {
    public let target: HueResourceReference
    public let action: HueLightAction
}

public struct HueSceneMetadata: Codable, Equatable, Sendable {
    public let name: String
}

public struct HuePaletteColor: Codable, Equatable, Sendable {
    public let color: HueColorAction
    public let dimming: HueDimmingAction
}

public struct HueScenePalette: Codable, Equatable, Sendable {
    public let color: [HuePaletteColor]
    public let dimming: [HueDimmingAction]
    public let colorTemperature: [HueColorTemperatureAction]
    public let effects: [String]

    public init(color: [HuePaletteColor]) {
        self.color = color
        self.dimming = []
        self.colorTemperature = []
        self.effects = []
    }

    enum CodingKeys: String, CodingKey {
        case color, dimming, effects
        case colorTemperature = "color_temperature"
    }
}

public struct HueSceneCreateRequest: Codable, Equatable, Sendable {
    public let metadata: HueSceneMetadata
    public let group: HueResourceReference
    public let actions: [HueSceneAction]
    public let palette: HueScenePalette
    public let speed: Double
    public let autoDynamic: Bool

    enum CodingKeys: String, CodingKey {
        case metadata, group, actions, palette, speed
        case autoDynamic = "auto_dynamic"
    }
}

public struct HueSceneUpdateRequest: Codable, Equatable, Sendable {
    public let metadata: HueSceneMetadata
    public let actions: [HueSceneAction]
    public let palette: HueScenePalette
    public let speed: Double
    public let autoDynamic: Bool

    enum CodingKeys: String, CodingKey {
        case metadata, actions, palette, speed
        case autoDynamic = "auto_dynamic"
    }
}

public struct HueSceneRecallRequest: Codable, Equatable, Sendable {
    public struct Recall: Codable, Equatable, Sendable {
        public let action: String
    }

    public let recall: Recall

    public init() {
        recall = Recall(action: "dynamic_palette")
    }
}

public struct HueSceneDraft: Equatable, Sendable {
    public let create: HueSceneCreateRequest
    public let update: HueSceneUpdateRequest
    public let animatedLightIDs: [HueResourceID]
}

public enum HueSceneBuilder {
    public static func build(
        area: HueArea,
        preset: HuePreset,
        contract: HueBoardContract,
        brightness: Double
    ) throws -> HueSceneDraft {
        let lights = area.dynamicLights
        guard !lights.isEmpty else {
            throw HueBoardError.unsupported(
                "This area has no non-streaming color lights that advertise dynamic palettes."
            )
        }
        guard let palette = contract.palette(index: preset.palette) else {
            throw HueBoardError.missingResource(
                "Preset palette \(preset.palette) is missing from the parity contract."
            )
        }
        let colors = try palette.decodedColors()
        guard colors.count == 4 else {
            throw HueBoardError.invalidResponse("Hue Board palettes must contain exactly four colors.")
        }
        let level = min(max(brightness, 5), lights.map(\.outputLimit).min() ?? 100)
        let actions = lights.enumerated().map { index, light in
            HueSceneAction(
                target: .init(resourceID: light.id, resourceType: "light"),
                action: .init(
                    on: .init(on: true),
                    dimming: .init(brightness: level),
                    color: .init(xy: HueColorMath.xy(colors[index % colors.count], gamut: light.gamut)),
                    dynamics: .init(duration: 2_500)
                )
            )
        }
        let payloadPalette = HueScenePalette(
            color: colors.map {
                .init(
                    color: .init(xy: HueColorMath.xy($0)),
                    dimming: .init(brightness: level)
                )
            }
        )
        let metadata = HueSceneMetadata(name: "Hue Board | \(palette.name)")
        let speed = (min(max(0.15 + preset.speed * 0.35, 0.1), 0.8) * 100).rounded() / 100
        let create = HueSceneCreateRequest(
            metadata: metadata,
            group: .init(resourceID: area.id, resourceType: area.kind.rawValue),
            actions: actions,
            palette: payloadPalette,
            speed: speed,
            autoDynamic: true
        )
        return .init(
            create: create,
            update: .init(
                metadata: metadata,
                actions: actions,
                palette: payloadPalette,
                speed: speed,
                autoDynamic: true
            ),
            animatedLightIDs: lights.map(\.id)
        )
    }
}

public struct HueLightSnapshot: Codable, Equatable, Sendable {
    public let lightID: HueResourceID
    public let action: HueLightAction
    public let capturedAt: Date

    public init(light: HueLight, capturedAt: Date = Date()) {
        lightID = light.id
        self.capturedAt = capturedAt

        // Hue resources can retain stale XY values while color temperature is the
        // active mode. A restore request must choose one mutually exclusive color mode.
        let temperature = light.colorTemperatureMirek.map(HueColorTemperatureAction.init(mirek:))
        let color = temperature == nil ? light.color.map(HueColorAction.init(xy:)) : nil

        action = .init(
            on: .init(on: light.isOn),
            dimming: light.brightness.map(HueDimmingAction.init(brightness:)),
            color: color,
            colorTemperature: temperature,
            dynamics: light.capabilities.dimming ? .init(duration: 1_500) : nil
        )
    }
}
