import Foundation

public struct HueRoomLayoutStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load(bridgeID: String, area: HueArea) throws -> HueRoomLayout {
        try SetupImportTransaction.withRecoveredSettings(defaults: defaults) {
            let key = SetupImportTransaction.Section.layout(bridgeID: bridgeID, areaID: area.id.rawValue).preferenceKey
            guard let raw = defaults.data(forKey: key) else {
                return .startingLayout(for: area)
            }
            let layout = try JSONDecoder().decode(HueRoomLayout.self, from: raw)
            return try layout.includingNewLights(from: area)
        }
    }

    public static func encoded(_ layout: HueRoomLayout, for area: HueArea) throws -> Data {
        try layout.validate(for: area)
        return try JSONEncoder().encode(layout)
    }

    public func save(_ layout: HueRoomLayout, bridgeID: String, area: HueArea) throws {
        let raw = try Self.encoded(layout, for: area)
        try SetupImportTransaction.withRecoveredSettings(defaults: defaults) {
            let key = SetupImportTransaction.Section.layout(bridgeID: bridgeID, areaID: area.id.rawValue).preferenceKey
            defaults.set(raw, forKey: key)
            guard defaults.data(forKey: key) == raw else {
                throw HueBoardError.invalidResponse("The saved room layout could not be verified.")
            }
        }
    }
}
