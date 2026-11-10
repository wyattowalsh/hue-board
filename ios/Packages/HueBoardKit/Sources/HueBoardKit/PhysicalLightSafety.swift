import Foundation

public struct PhysicalLightSafetySettings: Codable, Equatable, Sendable {
    public var warningAcknowledged: Bool
    public var reduceLightMotion: Bool
    public var maximumDynamicBrightness: Double

    public init(
        warningAcknowledged: Bool = false,
        reduceLightMotion: Bool = false,
        maximumDynamicBrightness: Double = 80
    ) {
        self.warningAcknowledged = warningAcknowledged
        self.reduceLightMotion = reduceLightMotion
        self.maximumDynamicBrightness = min(max(maximumDynamicBrightness, 10), 100)
    }

    public static let `default` = PhysicalLightSafetySettings()
}

public enum PhysicalLightSafetyPolicy {
    public static func clampedBrightness(
        _ value: Double,
        settings: PhysicalLightSafetySettings
    ) -> Double {
        min(max(value, 1), settings.maximumDynamicBrightness)
    }

    public static func adjustedEngineSettings(
        _ value: HueEngineSettings,
        safety: PhysicalLightSafetySettings
    ) -> HueEngineSettings {
        var result = value
        result.brightness = clampedBrightness(result.brightness, settings: safety)
        guard safety.reduceLightMotion else { return result }
        result.speed = min(result.speed, 0.55)
        result.energy = min(result.energy, 45)
        result.depth = min(result.depth, 50)
        result.tension = min(result.tension, 55)
        result.effectSpeed = min(result.effectSpeed, 0.25)
        result.phaseOffset = 0
        return result
    }

    public static func restTransitionMilliseconds(
        lightCount: Int,
        settings: PhysicalLightSafetySettings
    ) -> Int {
        let count = max(1, lightCount)
        if settings.reduceLightMotion {
            return max(8_000, count * 800)
        }
        return max(4_500, count * 550)
    }
}
