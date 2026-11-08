import Foundation
import HueBoardKit

#if canImport(CryptoKit) && canImport(JavaScriptCore)
import CryptoKit
import JavaScriptCore

public actor JavaScriptHueEngine: HueEngineSampling {
    private struct Manifest: Decodable { let schema: Int; let release: String; let sha256: String }
    private struct SamplePayload: Decodable { let rgb: [Double]; let brightness: Double }
    private let context: JSContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() throws {
        guard let runtimeURL = Bundle.module.url(forResource: "engine-runtime", withExtension: "js"),
              let manifestURL = Bundle.module.url(forResource: "engine-manifest", withExtension: "json") else {
            throw HueBoardError.missingResource("The shared Hue Board engine resources are missing.")
        }
        let runtimeData = try Data(contentsOf: runtimeURL)
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
        let digest = SHA256.hash(data: runtimeData).map { String(format: "%02x", $0) }.joined()
        guard manifest.schema == 1, manifest.sha256 == digest else {
            throw HueBoardError.invalidResponse("The bundled shared engine failed its integrity check.")
        }
        guard let context = JSContext() else {
            throw HueBoardError.invalidResponse("JavaScriptCore could not create the Hue Board engine context.")
        }
        self.context = context
        let runtime = String(decoding: runtimeData, as: UTF8.self)
        context.evaluateScript(runtime, withSourceURL: runtimeURL)
        if let exception = context.exception {
            throw HueBoardError.invalidResponse("Shared engine startup failed: \(exception.toString() ?? "unknown JavaScript error")")
        }
        guard context.objectForKeyedSubscript("HueBoardEngineBridge")?.isObject == true else {
            throw HueBoardError.invalidResponse("The shared engine bridge was not exported.")
        }
    }

    public func sample(
        time: Double,
        position: Double,
        settings: HueEngineSettings,
        surge: Double = 0
    ) throws -> HueLightFrame {
        let settingsJSON = try jsonLiteral(settings)
        let script = "JSON.stringify(HueBoardEngineBridge.sample(\(finite(time)),\(finite(position)),\(settingsJSON),\(finite(surge))))"
        let payload: SamplePayload = try evaluateJSON(script, as: SamplePayload.self)
        guard payload.rgb.count == 3, payload.rgb.allSatisfy(\.isFinite), payload.brightness.isFinite else {
            throw HueBoardError.invalidResponse("The shared engine returned a malformed light frame.")
        }
        return HueLightFrame(
            color: RGB(red: payload.rgb[0], green: payload.rgb[1], blue: payload.rgb[2]),
            brightness: payload.brightness
        )
    }

    public func xy(_ color: RGB, gamut: HueGamut? = nil) throws -> HueXY {
        let rgb = try jsonLiteral(color.components)
        let gamutJSON = try gamut.map(jsonLiteral) ?? "null"
        let value: HueXY = try evaluateJSON(
            "JSON.stringify(HueBoardEngineBridge.xy(\(rgb),\(gamutJSON)))",
            as: HueXY.self
        )
        guard value.x.isFinite, value.y.isFinite, value.x >= 0, value.y > 0, value.x + value.y <= 1.001 else {
            throw HueBoardError.invalidResponse("The shared engine returned an invalid Hue color point.")
        }
        return value
    }

    private func evaluateJSON<Value: Decodable>(_ script: String, as type: Value.Type) throws -> Value {
        context.exception = nil
        guard let output = context.evaluateScript(script)?.toString() else {
            let message = context.exception?.toString() ?? "no result"
            throw HueBoardError.invalidResponse("Shared engine evaluation failed: \(message)")
        }
        if let exception = context.exception {
            throw HueBoardError.invalidResponse("Shared engine evaluation failed: \(exception.toString() ?? "unknown error")")
        }
        return try decoder.decode(type, from: Data(output.utf8))
    }

    private func jsonLiteral<Value: Encodable>(_ value: Value) throws -> String {
        String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private func finite(_ value: Double) -> String {
        value.isFinite ? String(value) : "0"
    }
}

#else
public actor JavaScriptHueEngine: HueEngineSampling {
    public init() throws {
        throw HueBoardError.unsupported("JavaScriptCore is required for the shared Hue Board engine.")
    }
    public func sample(time: Double, position: Double, settings: HueEngineSettings, surge: Double = 0) throws -> HueLightFrame {
        throw HueBoardError.unsupported("JavaScriptCore is unavailable on this platform.")
    }
    public func xy(_ color: RGB, gamut: HueGamut? = nil) throws -> HueXY {
        throw HueBoardError.unsupported("JavaScriptCore is unavailable on this platform.")
    }
}
#endif
