import Foundation

public struct HueEngineGoldenManifest: Codable, Equatable, Sendable {
    public let schema: Int
    public let release: String
    public let algorithm: String
    public let numberFormat: String
    public let brightness: Double
    public let seed: Int
    public let topology: String
    public let times: [Double]
    public let positions: [Double]
    public let caseCount: Int
    public let sha256: String
    public let anchors: [HueEngineGoldenAnchor]
}

public struct HueEngineGoldenAnchor: Codable, Equatable, Sendable {
    public let preset: String
    public let time: Double
    public let position: Double
    public let rgb: [Double]
    public let brightness: Double
}

public enum HueEngineGoldenLoader {
    public static func load() throws -> HueEngineGoldenManifest {
        guard let url = Bundle.module.url(forResource: "engine-golden", withExtension: "json") else {
            throw HueBoardError.missingResource("The bundled engine parity manifest is missing.")
        }
        return try JSONDecoder().decode(
            HueEngineGoldenManifest.self,
            from: Data(contentsOf: url)
        )
    }
}
