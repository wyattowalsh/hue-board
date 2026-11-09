import Foundation

public struct HueResourceID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

public enum HueAreaKind: String, Codable, CaseIterable, Sendable { case room, zone }

public struct HueBridgeCandidate: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let host: String
    public let port: Int
    public init(id: String, host: String, port: Int = 443) {
        self.id = id.lowercased(); self.host = host; self.port = port
    }
}

public struct HueBridgeCredential: Codable, Equatable, Sendable {
    public let bridgeID: String
    public let applicationKey: String
    public let clientKey: String?
    public init(bridgeID: String, applicationKey: String, clientKey: String? = nil) {
        self.bridgeID = bridgeID.lowercased(); self.applicationKey = applicationKey; self.clientKey = clientKey
    }
}

public struct HueResourceReference: Codable, Equatable, Hashable, Sendable {
    public let resourceID: HueResourceID
    public let resourceType: String
    public init(resourceID: HueResourceID, resourceType: String) {
        self.resourceID = resourceID; self.resourceType = resourceType
    }
    enum CodingKeys: String, CodingKey { case resourceID = "rid"; case resourceType = "rtype" }
}

public struct HueXY: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct HueGamut: Codable, Equatable, Sendable {
    public let red: HueXY
    public let green: HueXY
    public let blue: HueXY
    public init(red: HueXY, green: HueXY, blue: HueXY) { self.red = red; self.green = green; self.blue = blue }
}

public struct RGB: Codable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public init(red: Double, green: Double, blue: Double) { self.red = red; self.green = green; self.blue = blue }
    public init(hex: String) throws {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count == 7, value.first == "#", let raw = Int(value.dropFirst(), radix: 16) else {
            throw HueBoardError.invalidColor(hex)
        }
        self.init(red: Double((raw >> 16) & 255) / 255, green: Double((raw >> 8) & 255) / 255, blue: Double(raw & 255) / 255)
    }
    public var components: [Double] { [red, green, blue] }
}

public struct HueLightCapabilities: Codable, Equatable, Sendable {
    public let power: Bool
    public let dimming: Bool
    public let color: Bool
    public let colorTemperature: Bool
    public let dynamicPalette: Bool
    public let gradientPoints: Int
    public let effects: [String]
    public let streaming: Bool
    public init(power: Bool, dimming: Bool, color: Bool, colorTemperature: Bool, dynamicPalette: Bool, gradientPoints: Int = 0, effects: [String] = [], streaming: Bool = false) {
        self.power = power; self.dimming = dimming; self.color = color; self.colorTemperature = colorTemperature
        self.dynamicPalette = dynamicPalette; self.gradientPoints = gradientPoints; self.effects = effects; self.streaming = streaming
    }
}

public struct HueLight: Codable, Equatable, Identifiable, Sendable {
    public let id: HueResourceID
    public let ownerID: HueResourceID?
    public let name: String
    public let isOn: Bool
    public let brightness: Double?
    public let color: HueXY?
    public let colorTemperatureMirek: Int?
    public let dynamicStatus: String?
    public let gamut: HueGamut?
    public let capabilities: HueLightCapabilities
    public let outputLimit: Double
    public init(id: HueResourceID, ownerID: HueResourceID?, name: String, isOn: Bool, brightness: Double?, color: HueXY?, colorTemperatureMirek: Int?, dynamicStatus: String? = nil, gamut: HueGamut?, capabilities: HueLightCapabilities, outputLimit: Double = 100) {
        self.id=id; self.ownerID=ownerID; self.name=name; self.isOn=isOn; self.brightness=brightness; self.color=color
        self.colorTemperatureMirek=colorTemperatureMirek; self.dynamicStatus=dynamicStatus; self.gamut=gamut; self.capabilities=capabilities
        self.outputLimit=min(max(outputLimit,1),100)
    }
}

public struct HueArea: Codable, Equatable, Identifiable, Sendable {
    public let id: HueResourceID
    public let kind: HueAreaKind
    public let name: String
    public let lights: [HueLight]
    public init(id: HueResourceID, kind: HueAreaKind, name: String, lights: [HueLight]) { self.id=id; self.kind=kind; self.name=name; self.lights=lights }
    public var dynamicLights: [HueLight] { lights.filter { $0.capabilities.color && $0.capabilities.dynamicPalette && !$0.capabilities.streaming } }
}

public struct HuePattern: Codable, Equatable, Identifiable, Sendable { public let id: String; public let name: String }
public struct HuePalette: Codable, Equatable, Identifiable, Sendable {
    public let index: Int; public let name: String; public let colors: [String]
    public var id: Int { index }
    public func decodedColors() throws -> [RGB] { try colors.map(RGB.init(hex:)) }
}
public struct HuePreset: Codable, Equatable, Identifiable, Sendable {
    public let id: String; public let name: String; public let category: String; public let description: String
    public let pattern: String; public let palette: Int; public let speed: Double; public let energy: Double; public let depth: Double; public let focus: Double
}
public struct HueBoardContract: Codable, Equatable, Sendable {
    public let schema: Int; public let release: String; public let patterns: [HuePattern]; public let palettes: [HuePalette]; public let presets: [HuePreset]
    public func preset(id: String) -> HuePreset? { presets.first { $0.id == id } }
    public func palette(index: Int) -> HuePalette? { palettes.first { $0.index == index } }
}

public struct HueEngineSettings: Codable, Equatable, Sendable {
    public var showA: String; public var showB: String; public var paletteA: Int; public var paletteB: Int; public var morph: Double
    public var brightness: Double; public var speed: Double; public var depth: Double; public var spread: Double; public var energy: Double
    public var tension: Double; public var focus: Double; public var reverse: Bool; public var gradient: Bool; public var seed: Int
    public var topology: String; public var saturation: Double; public var ambientFloor: Double; public var accentMix: Double
    public var density: Int; public var phaseOffset: Double; public var brightnessCurve: Double; public var directorSeconds: Double
    public var customColors: [String]
    public init(showA: String = "eclipse", showB: String = "turbine", paletteA: Int = 0, paletteB: Int = 1, morph: Double = 0, brightness: Double = 60, speed: Double = 1, depth: Double = 75, spread: Double = 1.2, energy: Double = 65, tension: Double = 65, focus: Double = 55, reverse: Bool = false, gradient: Bool = false, seed: Int = 731, topology: String = "ring", saturation: Double = 100, ambientFloor: Double = 0, accentMix: Double = 100, density: Int = 1, phaseOffset: Double = 0, brightnessCurve: Double = 1, directorSeconds: Double = 52, customColors: [String] = ["#102CBA","#00B9F2","#36E5D1","#A4ED51"]) {
        self.showA=showA; self.showB=showB; self.paletteA=paletteA; self.paletteB=paletteB; self.morph=morph; self.brightness=brightness
        self.speed=speed; self.depth=depth; self.spread=spread; self.energy=energy; self.tension=tension; self.focus=focus
        self.reverse=reverse; self.gradient=gradient; self.seed=seed; self.topology=topology; self.saturation=saturation
        self.ambientFloor=ambientFloor; self.accentMix=accentMix; self.density=density; self.phaseOffset=phaseOffset
        self.brightnessCurve=brightnessCurve; self.directorSeconds=directorSeconds; self.customColors=customColors
    }
    public static func from(preset: HuePreset, brightness: Double = 60) -> Self {
        .init(showA:preset.pattern,showB:preset.pattern,paletteA:preset.palette,paletteB:preset.palette,brightness:brightness,speed:preset.speed,depth:preset.depth,energy:preset.energy,focus:preset.focus)
    }
}

public struct HueLightFrame: Codable, Equatable, Sendable { public let color: RGB; public let brightness: Double }

public protocol HueEngineSampling: Sendable {
    func sample(time: Double, position: Double, settings: HueEngineSettings, surge: Double) async throws -> HueLightFrame
    func xy(_ color: RGB, gamut: HueGamut?) async throws -> HueXY
}

public enum HueColorMath {
    public static func xy(_ color: RGB, gamut: HueGamut? = nil) -> HueXY {
        func linear(_ v: Double)->Double { v <= 0.04045 ? v / 12.92 : Foundation.pow((v + 0.055) / 1.055, 2.4) }
        let r=linear(color.red),g=linear(color.green),b=linear(color.blue)
        let x=r*0.4124564+g*0.3575761+b*0.1804375, y=r*0.2126729+g*0.7151522+b*0.072175, z=r*0.0193339+g*0.119192+b*0.9503041
        let total=x+y+z; var point=total > 1e-12 ? HueXY(x:x/total,y:y/total) : HueXY(x:0.3127,y:0.329)
        if let gamut { point=clip(point,gamut:gamut) }
        return HueXY(x:(point.x*1_000_000).rounded()/1_000_000,y:(point.y*1_000_000).rounded()/1_000_000)
    }
    private static func clip(_ p: HueXY,gamut:HueGamut)->HueXY {
        let pts=[gamut.red,gamut.green,gamut.blue]
        func cross(_ a:HueXY,_ b:HueXY,_ c:HueXY)->Double { (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x) }
        guard abs(cross(pts[0],pts[1],pts[2])) >= 1e-9 else { return p }
        let signs=[cross(pts[0],pts[1],p),cross(pts[1],pts[2],p),cross(pts[2],pts[0],p)]
        if signs.allSatisfy({$0 >= -1e-10}) || signs.allSatisfy({$0 <= 1e-10}) { return p }
        return (0..<3).map { i -> HueXY in let a=pts[i],b=pts[(i+1)%3],dx=b.x-a.x,dy=b.y-a.y,d=dx*dx+dy*dy,u=d>0 ? min(max(((p.x-a.x)*dx+(p.y-a.y)*dy)/d,0),1):0; return HueXY(x:a.x+u*dx,y:a.y+u*dy) }.min { a,b in Foundation.pow(a.x-p.x,2)+Foundation.pow(a.y-p.y,2) < Foundation.pow(b.x-p.x,2)+Foundation.pow(b.y-p.y,2) } ?? p
    }
}

public enum HueBridgeHostValidator {
    public static func isAllowed(_ host: String) -> Bool {
        let value=host.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        guard !value.isEmpty,!value.contains("/"),!value.contains("\\"),!value.contains("@") else{return false}
        if value.hasSuffix(".local") { return value.split(separator:".").allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } } }
        let parts=value.split(separator:".",omittingEmptySubsequences:false),octets=parts.compactMap{Int($0)}
        guard parts.count==4,octets.count==4,octets.allSatisfy({(0...255).contains($0)}) else{return false}
        return octets[0]==10 || (octets[0]==172 && (16...31).contains(octets[1])) || (octets[0]==192 && octets[1]==168)
    }
}

public enum HueBoardError: Error, Equatable, LocalizedError, Sendable {
    case invalidColor(String),missingResource(String),unsupported(String),invalidResponse(String),authorization(String),network(String),cancelled
    public var errorDescription: String? { switch self { case .invalidColor(let v):"Invalid color: \(v)"; case .missingResource(let v),.unsupported(let v),.invalidResponse(let v),.authorization(let v),.network(let v):v; case .cancelled:"The operation was cancelled." } }
}
