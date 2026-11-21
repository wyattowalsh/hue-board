import CryptoKit
import Foundation
import HueBoardKit

/// The default harness rejects rendering. Its optional Linux path evaluates the shipped
/// deterministic JS bridge in a fresh JavaScriptCoreGTK process for each operation.
actor JavaScriptHueEngine: HueEngineSampling {
    private struct Manifest: Decodable { let schema: Int; let sha256: String }
    private struct Sample: Decodable { let rgb: [Double]; let brightness: Double }
    private let executable: URL?
    private let runtime: URL?

    init() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["HUE_MODEL_JSC"] else {
            executable = nil
            runtime = nil
            return
        }
        guard let pathToResources = env["HUE_MODEL_ENGINE_RESOURCES"] else {
            throw HueBoardError.missingResource("The harness requires the package engine resources.")
        }
        let resources = URL(fileURLWithPath: pathToResources)
        let runtime = resources.appendingPathComponent("engine-runtime.js")
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(
            contentsOf: resources.appendingPathComponent("engine-manifest.json")
        ))
        let digest = SHA256.hash(data: try Data(contentsOf: runtime))
            .map { String(format: "%02x", $0) }.joined()
        guard manifest.schema == 1, digest == manifest.sha256 else {
            throw HueBoardError.invalidResponse("The shared engine fingerprint does not match.")
        }
        self.executable = URL(fileURLWithPath: path)
        self.runtime = runtime
    }

    func sample(time: Double, position: Double, settings: HueEngineSettings, surge: Double = 0) throws -> HueLightFrame {
        let t = time.isFinite ? time : 0
        let q = position.isFinite ? position : 0
        let s = surge.isFinite ? surge : 0
        let call = "HueBoardEngineBridge.sample(\(t),\(q),\(try json(settings)),\(s))"
        let frame: Sample = try evaluate(call)
        guard frame.rgb.count == 3, frame.rgb.allSatisfy(\.isFinite), frame.brightness.isFinite else {
            throw HueBoardError.invalidResponse("JavaScriptCoreGTK returned an invalid sample.")
        }
        return HueLightFrame(color: RGB(red: frame.rgb[0], green: frame.rgb[1], blue: frame.rgb[2]),
                             brightness: frame.brightness)
    }

    func xy(_ color: RGB, gamut: HueGamut? = nil) throws -> HueXY {
        let point: HueXY = try evaluate("HueBoardEngineBridge.xy(\(try json(color.components)),\(try json(gamut)))")
        guard point.x.isFinite, point.y.isFinite, point.x >= 0, point.y > 0, point.x + point.y <= 1.001 else {
            throw HueBoardError.invalidResponse("JavaScriptCoreGTK returned an invalid Hue point.")
        }
        return point
    }

    private func json(_ value: some Encodable) throws -> String {
        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }

    private func evaluate<T: Decodable>(_ call: String) throws -> T {
        guard let executable, let runtime else {
            preconditionFailure("Unexpected engine evaluation in the default Linux harness")
        }
        let process = Process()
        process.executableURL = executable
        if let libs = ProcessInfo.processInfo.environment["HUE_MODEL_JSC_LIBRARIES"] {
            var env = ProcessInfo.processInfo.environment
            env["LD_LIBRARY_PATH"] = libs
            process.environment = env
        }
        process.arguments = [runtime.path, "-e", "print(JSON.stringify(\(call)))"]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let bytes = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw HueBoardError.invalidResponse("JavaScriptCoreGTK exited with status \(process.terminationStatus).")
        }
        return try JSONDecoder().decode(T.self, from: bytes)
    }
}
