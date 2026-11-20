import Foundation

public struct HueRoomLayoutStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(bridgeID: String, areaID: HueResourceID) -> String {
        "hue-board.native.layout.v1.\(bridgeID).\(areaID.rawValue)"
    }

    public func load(bridgeID: String, area: HueArea) throws -> HueRoomLayout {
        let key = key(bridgeID: bridgeID, areaID: area.id)
        guard let raw = defaults.data(forKey: key) else {
            return .startingLayout(for: area)
        }
        let layout = try JSONDecoder().decode(HueRoomLayout.self, from: raw)
        return try layout.includingNewLights(from: area)
    }

    public func save(_ layout: HueRoomLayout, bridgeID: String, area: HueArea) throws {
        try layout.validate(for: area)
        let raw = try JSONEncoder().encode(layout)
        let key = key(bridgeID: bridgeID, areaID: area.id)
        defaults.set(raw, forKey: key)
        guard defaults.data(forKey: key) == raw else {
            throw HueBoardError.invalidResponse("The saved room layout could not be verified.")
        }
    }
}
