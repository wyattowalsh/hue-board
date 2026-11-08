import Foundation

public struct HueBoardContract: Codable, Equatable, Sendable {
  public let schema: Int
  public let release: String
  public let defaults: HueEngineSettings
  public let patterns: [HuePatternDefinition]
  public let palettes: [HuePaletteDefinition]
  public let presets: [HuePresetDefinition]

  public func preset(id: String) -> HuePresetDefinition? {
    presets.first { $0.id == id }
  }
}

public struct HuePatternDefinition: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
}

public struct HuePaletteDefinition: Codable, Equatable, Identifiable, Sendable {
  public var id: Int { index }
  public let index: Int
  public let name: String
  public let colors: [String]
}

public struct HuePresetDefinition: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let category: String
  public let description: String
  public let settings: HueEngineSettings
}

public struct HueEngineGoldenSuite: Codable, Equatable, Sendable {
  public let schema: Int
  public let release: String
  public let cases: [HueEngineGoldenCase]
}

public struct HueEngineGoldenCase: Codable, Equatable, Sendable {
  public let preset: String
  public let time: Double
  public let position: Double
  public let rgb: [Double]
  public let brightness: Double
}

public enum HueBoardResources {
  public static func contract() throws -> HueBoardContract {
    try decode(name: "hue-board-contract", as: HueBoardContract.self)
  }

  public static func goldenSuite() throws -> HueEngineGoldenSuite {
    try decode(name: "engine-golden", as: HueEngineGoldenSuite.self)
  }

  private static func decode<T: Decodable>(name: String, as type: T.Type) throws -> T {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
      throw HueBoardResourceError.missing(name)
    }
    do {
      return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    } catch {
      throw HueBoardResourceError.invalid(name, error)
    }
  }
}

public enum HueBoardResourceError: Error, LocalizedError {
  case missing(String)
  case invalid(String, Error)

  public var errorDescription: String? {
    switch self {
    case .missing(let name):
      return "Missing bundled resource: \(name).json"
    case .invalid(let name, let error):
      return "Invalid bundled resource \(name).json: \(error.localizedDescription)"
    }
  }
}
