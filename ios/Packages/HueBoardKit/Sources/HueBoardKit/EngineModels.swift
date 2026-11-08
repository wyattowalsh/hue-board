import Foundation

public enum HueTopology: String, Codable, CaseIterable, Sendable {
  case ring
  case path
}

public struct HueEngineSettings: Codable, Equatable, Sendable {
  public var showA: String
  public var showB: String
  public var paletteA: Int
  public var paletteB: Int
  public var morph: Double
  public var brightness: Double
  public var speed: Double
  public var depth: Double
  public var spread: Double
  public var energy: Double
  public var tension: Double
  public var focus: Double
  public var reverse: Bool
  public var gradient: Bool
  public var seed: Int
  public var topology: HueTopology
  public var transitionMs: Double
  public var ownership: String
  public var nativeKind: String
  public var effect: String
  public var effectSpeed: Double
  public var effectTint: Bool
  public var saturation: Double
  public var ambientFloor: Double
  public var accentMix: Double
  public var density: Int
  public var phaseOffset: Double
  public var brightnessCurve: Double
  public var directorSeconds: Double
  public var customColors: [String]
  public var sequenceIds: [String]
  public var sequenceHold: Double
  public var sequenceOrder: String
}

public struct HueRGB: Codable, Equatable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double

  public init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  public init(_ values: [Double]) {
    precondition(values.count == 3)
    self.init(red: values[0], green: values[1], blue: values[2])
  }

  public var array: [Double] { [red, green, blue] }
}

public struct HueFrame: Codable, Equatable, Sendable {
  public var rgb: HueRGB
  public var brightness: Double

  public init(rgb: HueRGB, brightness: Double) {
    self.rgb = rgb
    self.brightness = brightness
  }
}

public struct HueChromaticity: Codable, Equatable, Sendable {
  public var x: Double
  public var y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

public struct HueGamut: Codable, Equatable, Sendable {
  public var red: HueChromaticity
  public var green: HueChromaticity
  public var blue: HueChromaticity

  public init(red: HueChromaticity, green: HueChromaticity, blue: HueChromaticity) {
    self.red = red
    self.green = green
    self.blue = blue
  }
}
