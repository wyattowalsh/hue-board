import Foundation
import HueBoardKit
import HueBoardNativeCore

struct NativeLiveProgress: Equatable, Sendable {
    let fraction: Double
    let elapsed: TimeInterval
    let remaining: TimeInterval
    let writes: Int
}

actor NativeLiveRunner {
    private let client: HueBridgeClient
    private let engine: any HueEngineSampling
    private var running = false

    init(client: HueBridgeClient, engine: any HueEngineSampling) {
        self.client = client
        self.engine = engine
    }

    func run(
        profile: BridgeProfile,
        credential: HueBridgeCredential,
        area: HueArea,
        preset: HuePreset,
        brightness: Double,
        duration: TimeInterval,
        progress: @escaping @Sendable (NativeLiveProgress) async -> Void
    ) async throws {
        guard !running else { throw HueBoardError.unsupported("A Native Live session is already running.") }
        let lights = area.lights.filter {
            $0.capabilities.color && $0.capabilities.dimming && !$0.capabilities.streaming
        }
        guard !lights.isEmpty else {
            throw HueBoardError.unsupported("No non-streaming color lights are available for Native Live.")
        }
        guard duration > 0 else { throw HueBoardError.unsupported("Choose a positive Live duration.") }
        running = true
        defer { running = false }

        let settings = HueEngineSettings.from(preset: preset, brightness: brightness)
        let clock = ContinuousClock()
        let started = clock.now
        let transition = max(4_500, lights.count * 550)
        var writes = 0

        while true {
            try Task.checkCancellation()
            let elapsed = started.duration(to: clock.now).seconds
            if elapsed >= duration { break }
            for (index, light) in lights.enumerated() {
                try Task.checkCancellation()
                let current = started.duration(to: clock.now).seconds
                if current >= duration { break }
                let position = Double(index) / Double(max(1, lights.count))
                let frame = try await engine.sample(
                    time: current,
                    position: position,
                    settings: settings,
                    surge: 0
                )
                let xy = try await engine.xy(frame.color, gamut: light.gamut)
                try await client.updateLight(
                    id: light.id,
                    action: HueLightAction(
                        on: HueOnAction(on: true),
                        dimming: HueDimmingAction(brightness: min(frame.brightness, light.outputLimit)),
                        color: HueColorAction(xy: xy),
                        dynamics: HueDynamicsAction(duration: transition)
                    ),
                    profile: profile,
                    credential: credential
                )
                writes += 1
                await progress(
                    NativeLiveProgress(
                        fraction: min(1, current / duration),
                        elapsed: current,
                        remaining: max(0, duration - current),
                        writes: writes
                    )
                )
            }
        }
        await progress(.init(fraction: 1, elapsed: duration, remaining: 0, writes: writes))
    }
}

private extension Duration {
    var seconds: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
