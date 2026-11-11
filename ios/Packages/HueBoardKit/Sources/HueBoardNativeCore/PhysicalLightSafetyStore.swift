import Foundation
import HueBoardKit

public actor PhysicalLightSafetyStore {
    public static let shared = PhysicalLightSafetyStore()

    private struct Envelope: Codable, Equatable, Sendable {
        let schema: Int
        let payload: PhysicalLightSafetySettings
        let payloadSHA256: String
    }

    private enum Key {
        static let settings = "hue-board.native.physical-light-safety.v1"
        static let quarantine = "hue-board.native.physical-light-safety.quarantine.v1"
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(suiteName: String? = nil) {
        defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
    }

    public func load() -> PhysicalLightSafetySettings {
        guard let data = defaults.data(forKey: Key.settings) else {
            return .default
        }
        do {
            let envelope = try decoder.decode(Envelope.self, from: data)
            guard envelope.schema == 1 else {
                throw PhysicalLightSafetyStoreError.unsupportedSchema(envelope.schema)
            }
            let payload = try encoder.encode(envelope.payload)
            guard digest(payload) == envelope.payloadSHA256 else {
                throw PhysicalLightSafetyStoreError.integrityMismatch
            }
            return envelope.payload
        } catch {
            defaults.set(data, forKey: Key.quarantine)
            defaults.removeObject(forKey: Key.settings)
            return .default
        }
    }

    public func save(_ settings: PhysicalLightSafetySettings) throws {
        let payload = try encoder.encode(settings)
        let envelope = Envelope(
            schema: 1,
            payload: settings,
            payloadSHA256: digest(payload)
        )
        defaults.set(try encoder.encode(envelope), forKey: Key.settings)
    }

    public func quarantinedDataForTesting() -> Data? {
        defaults.data(forKey: Key.quarantine)
    }

    private func digest(_ data: Data) -> String {
        PersistenceChecksum.sha256Hex(data)
    }
}

public enum PhysicalLightSafetyStoreError: Error, LocalizedError, Sendable {
    case unsupportedSchema(Int)
    case integrityMismatch

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let schema):
            return "Unsupported physical-light safety schema \(schema)."
        case .integrityMismatch:
            return "Physical-light safety settings failed their integrity check."
        }
    }
}
