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
        static let settings = SetupImportTransaction.Section.safety.preferenceKey
        static let quarantine = "hue-board.native.physical-light-safety.quarantine.v1"
    }

    private let defaults: UserDefaults

    public init(suiteName: String? = nil) {
        defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func load() -> PhysicalLightSafetySettings {
        Self.loadSynchronously(defaults: defaults)
    }

    public static func loadSynchronously(defaults: UserDefaults = .standard) -> PhysicalLightSafetySettings {
        do {
            return try SetupImportTransaction.withRecoveredSettings(defaults: defaults) {
                guard let data = defaults.data(forKey: Key.settings) else {
                    return defaults.data(forKey: Key.quarantine) != nil ? .failedClosed : .default
                }
                do {
                    let envelope = try JSONDecoder().decode(Envelope.self, from: data)
                    guard envelope.schema == 1 else {
                        throw PhysicalLightSafetyStoreError.unsupportedSchema(envelope.schema)
                    }
                    let payload = try Self.encoder().encode(envelope.payload)
                    guard PersistenceChecksum.sha256Hex(payload) == envelope.payloadSHA256 else {
                        throw PhysicalLightSafetyStoreError.integrityMismatch
                    }
                    return envelope.payload
                } catch {
                    let safe = try Self.encoded(.failedClosed)
                    defaults.set(data, forKey: Key.quarantine)
                    defaults.set(safe, forKey: Key.settings)
                    return .failedClosed
                }
            }
        } catch {
            // Keep an unreadable setup transaction untouched for diagnosis.
            return .failedClosed
        }
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func encoded(_ settings: PhysicalLightSafetySettings) throws -> Data {
        let encoder = encoder()
        let payload = try encoder.encode(settings)
        return try encoder.encode(Envelope(
            schema: 1, payload: settings, payloadSHA256: PersistenceChecksum.sha256Hex(payload)
        ))
    }

    public static func saveSynchronously(
        _ settings: PhysicalLightSafetySettings, defaults: UserDefaults = .standard
    ) throws {
        let data = try encoded(settings)
        try SetupImportTransaction.withRecoveredSettings(defaults: defaults) {
            defaults.set(data, forKey: Key.settings)
            guard defaults.data(forKey: Key.settings) == data else {
                throw HueBoardError.invalidResponse("The physical-light safety settings write did not verify.")
            }
        }
    }

    public func save(_ settings: PhysicalLightSafetySettings) throws {
        try Self.saveSynchronously(settings, defaults: defaults)
    }

    public func quarantinedDataForTesting() -> Data? {
        defaults.data(forKey: Key.quarantine)
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
