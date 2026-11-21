import Foundation

/// Serializes only the four durable user-editable setup sections. Existing preference keys
/// and value formats remain authoritative. A prepared import rolls back on the next read,
/// while a committed import replays. Both operations are idempotent.
public enum SetupImportTransaction {
    public enum Section: Hashable, Codable, Sendable {
        case library
        case favorites
        case safety
        case layout(bridgeID: String, areaID: String)

        public var preferenceKey: String {
            switch self {
            case .library: "hue-board.native.studio-documents.v1"
            case .favorites: "hue-board.native.favorite-presets.v1"
            case .safety: "hue-board.native.physical-light-safety.v1"
            case .layout(let bridgeID, let areaID): "hue-board.native.layout.v1.\(bridgeID).\(areaID)"
            }
        }
    }

    public enum Value: Codable, Equatable, Sendable {
        case data(Data)
        case identifiers([String])
        case absent
    }

    public struct Fingerprint: Equatable, Sendable {
        fileprivate let values: [Section: Value]
    }

    private struct Change: Codable {
        let section: Section
        let previous: Value
        let proposed: Value
    }

    private enum Phase: String, Codable { case prepared, committed }

    private struct Record: Codable {
        let schema: Int
        var phase: Phase
        let changes: [Change]
    }

    private struct Envelope: Codable {
        let payload: Data
        let sha256: String
    }

    enum Checkpoint: Equatable { case beforePrepare, prepared, applied(Int), committed }

    private static let lock = NSLock()
    private static let recordKey = "hue-board.native.setup-import-transaction.v1"

    /// All ordinary readers and writers of these sections also pass here. A concurrent
    /// read cannot observe a partially-applied import and a later save cannot be replayed over.
    public static func withRecoveredSettings<T>(
        defaults: UserDefaults,
        _ operation: () throws -> T
    ) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        try recoverLocked(defaults)
        return try operation()
    }

    public static func recover(defaults: UserDefaults = .standard) throws {
        try withRecoveredSettings(defaults: defaults) {}
    }

    public static func loadFavorites(defaults: UserDefaults = .standard) throws -> Set<String> {
        try withRecoveredSettings(defaults: defaults) {
            guard defaults.object(forKey: Section.favorites.preferenceKey) != nil else { return [] }
            guard let ids = defaults.array(forKey: Section.favorites.preferenceKey) as? [String] else {
                throw HueBoardError.invalidResponse("Saved favorites could not be read.")
            }
            return Set(ids)
        }
    }

    public static func saveFavorites(_ ids: Set<String>, defaults: UserDefaults = .standard) throws {
        try withRecoveredSettings(defaults: defaults) {
            try apply(.identifiers(ids.sorted()), to: .favorites, in: defaults)
        }
    }

    public static func fingerprint(
        for sections: Set<Section>, defaults: UserDefaults = .standard
    ) throws -> Fingerprint {
        try withRecoveredSettings(defaults: defaults) {
            try fingerprintLocked(sections, defaults)
        }
    }

    public static func commit(
        _ proposed: [Section: Value], expected: Fingerprint, defaults: UserDefaults = .standard
    ) throws {
        try commit(proposed, expected: expected, defaults: defaults, checkpoint: { _ in })
    }

    /// A thrown checkpoint models a process exit after that exact persistence boundary.
    static func commit(
        _ proposed: [Section: Value], expected: Fingerprint, defaults: UserDefaults,
        checkpoint: (Checkpoint) throws -> Void
    ) throws {
        try withRecoveredSettings(defaults: defaults) {
            let current = try fingerprintLocked(Set(proposed.keys), defaults)
            guard current == expected else {
                throw HueBoardError.invalidResponse("These settings changed. Review the import again.")
            }
            let changes = try proposed.sorted { $0.key.preferenceKey < $1.key.preferenceKey }.compactMap { item -> Change? in
                let (section, value) = item
                try validate(value, for: section)
                guard value != .absent, let previous = current.values[section] else {
                    throw HueBoardError.invalidResponse("A setup import requires a replacement for each selected section.")
                }
                return previous == value ? nil : Change(section: section, previous: previous, proposed: value)
            }
            guard !changes.isEmpty else { return }
            var record = Record(schema: 1, phase: .prepared, changes: changes)
            try checkpoint(.beforePrepare)
            try save(record, in: defaults)
            try checkpoint(.prepared)
            for (index, change) in changes.enumerated() {
                try apply(change.proposed, to: change.section, in: defaults)
                try checkpoint(.applied(index))
            }
            // Flush the originals' replacements before making commit durable. A
            // failure here leaves the prepared marker intact for rollback on next use.
            try flush(defaults)
            record.phase = .committed
            do {
                try save(record, in: defaults)
            } catch {
                record.phase = .prepared
                try save(record, in: defaults)
                try recoverLocked(defaults)
                throw error
            }
            try checkpoint(.committed)
            // A committed marker can safely survive process death during cleanup.
            try? retireRecord(defaults)
        }
    }

    private static func fingerprintLocked(_ sections: Set<Section>, _ defaults: UserDefaults) throws -> Fingerprint {
        guard Set(sections.map(\.preferenceKey)).count == sections.count else {
            throw HueBoardError.invalidResponse("Duplicate destinations in setup import.")
        }
        var values: [Section: Value] = [:]
        for section in sections {
            values[section] = try read(section, defaults)
        }
        return Fingerprint(values: values)
    }

    private static func read(_ section: Section, _ defaults: UserDefaults) throws -> Value {
        guard let object = defaults.object(forKey: section.preferenceKey) else { return .absent }
        if section == .favorites, let ids = object as? [String] { return .identifiers(ids) }
        if section != .favorites, let data = object as? Data { return .data(data) }
        throw HueBoardError.invalidResponse("An existing setup section has an unreadable value. Its contents were preserved.")
    }

    private static func validate(_ value: Value, for section: Section) throws {
        switch (section, value) {
        case (_, .absent), (.favorites, .identifiers), (.library, .data), (.safety, .data), (.layout, .data): return
        default: throw HueBoardError.invalidResponse("The stored setup section has an unexpected format.")
        }
    }

    private static func apply(_ value: Value, to section: Section, in defaults: UserDefaults) throws {
        switch value {
        case .data(let data): defaults.set(data, forKey: section.preferenceKey)
        case .identifiers(let ids): defaults.set(ids, forKey: section.preferenceKey)
        case .absent: defaults.removeObject(forKey: section.preferenceKey)
        }
        guard try read(section, defaults) == value else {
            throw HueBoardError.invalidResponse("The local setup write did not verify.")
        }
    }

    private static func save(_ record: Record, in defaults: UserDefaults) throws {
        let encoder = PropertyListEncoder()
        let payload = try encoder.encode(record)
        let data = try encoder.encode(Envelope(payload: payload, sha256: PersistenceChecksum.sha256Hex(payload)))
        defaults.set(data, forKey: recordKey)
        guard defaults.data(forKey: recordKey) == data else {
            throw HueBoardError.invalidResponse("The local setup transaction could not be persisted.")
        }
        try flush(defaults)
    }

    private static func flush(_ defaults: UserDefaults) throws {
        // The order of these durable barriers is part of the write-ahead protocol.
        guard defaults.synchronize() else {
            throw HueBoardError.invalidResponse("The local setup could not be saved durably.")
        }
    }

    private static func recoverLocked(_ defaults: UserDefaults) throws {
        guard let stored = defaults.object(forKey: recordKey) else { return }
        guard let data = stored as? Data else {
            throw HueBoardError.invalidResponse("The pending local setup update is unreadable.")
        }
        let decoder = PropertyListDecoder()
        let envelope = try decoder.decode(Envelope.self, from: data)
        guard PersistenceChecksum.sha256Hex(envelope.payload) == envelope.sha256 else {
            throw HueBoardError.invalidResponse("The pending local setup update failed its integrity check.")
        }
        let record = try decoder.decode(Record.self, from: envelope.payload)
        guard record.schema == 1, !record.changes.isEmpty,
              Set(record.changes.map { $0.section.preferenceKey }).count == record.changes.count else {
            throw HueBoardError.invalidResponse("The pending local setup update could not be verified.")
        }
        for change in record.changes {
            try validate(change.previous, for: change.section)
            try validate(change.proposed, for: change.section)
        }
        for change in record.changes {
            try apply(record.phase == .committed ? change.proposed : change.previous, to: change.section, in: defaults)
        }
        try flush(defaults)
        try retireRecord(defaults)
    }

    private static func retireRecord(_ defaults: UserDefaults) throws {
        guard let stored = defaults.data(forKey: recordKey) else { return }
        defaults.removeObject(forKey: recordKey)
        // Do not expose an ordinary writer until marker removal is durable.
        do {
            try flush(defaults)
        } catch {
            defaults.set(stored, forKey: recordKey)
            throw error
        }
    }
}
