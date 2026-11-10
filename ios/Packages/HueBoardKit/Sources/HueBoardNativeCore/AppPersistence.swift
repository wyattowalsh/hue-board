import Foundation
import HueBoardKit

public actor AppPersistence {
    public static let shared = AppPersistence()

    private enum Key {
        static let stateV2 = "hue-board.native.state.v2"
        static let recoveryV2 = "hue-board.native.recovery.v2"
        static let migrationReportV2 = "hue-board.native.migration-report.v2"
        static let legacyBackupV1 = "hue-board.native.legacy-backup.v1"
        static let quarantineV2 = "hue-board.native.quarantine.v2"

        static let legacyProfile = "hue-board.native.profile.v1"
        static let legacySelectedArea = "hue-board.native.selected-area.v1"
        static let legacySceneRegistry = "hue-board.native.scene-registry.v1"
        static let legacyRestoreJournal = "hue-board.native.restore-journal.v1"
        static let legacyLiveDescriptor = "hue-board.native.live-descriptor.v1"
        static let legacyLiveStatus = "hue-board.native.live-status.v1"
    }

    private let defaults: UserDefaults
    private let writerVersion: String
    private var cachedState: NativeAppState?

    public init(
        suiteName: String? = nil,
        writerVersion: String = NativePersistenceVersion.defaultWriterVersion
    ) {
        defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        self.writerVersion = writerVersion
    }

    public func loadProfile() throws -> BridgeProfile? {
        try loadState().activeProfile
    }

    public func loadProfiles() throws -> [BridgeProfile] {
        try loadState().profiles.values.sorted { $0.bridgeID < $1.bridgeID }
    }

    public func saveProfile(_ profile: BridgeProfile?) throws {
        try updateState { state in
            if let profile {
                state.profiles[profile.bridgeID] = profile
                state.activeBridgeID = profile.bridgeID
            } else {
                state.activeBridgeID = nil
            }
        }
    }

    public func activateProfile(bridgeID: String) throws {
        try updateState { state in
            guard state.profiles[bridgeID] != nil else {
                throw PersistenceError.unknownBridge(bridgeID)
            }
            state.activeBridgeID = bridgeID
        }
    }

    public func loadSelectedAreaID(bridgeID: String) throws -> HueResourceID? {
        guard let rawValue = try loadState().selectedAreaIDs[bridgeID] else { return nil }
        return .init(rawValue: rawValue)
    }

    public func saveSelectedAreaID(_ areaID: HueResourceID?, bridgeID: String) throws {
        try updateState { state in
            state.selectedAreaIDs[bridgeID] = areaID?.rawValue
        }
    }

    public func sceneID(bridgeID: String, areaID: HueResourceID) throws -> HueResourceID? {
        let key = Self.sceneKey(bridgeID: bridgeID, areaID: areaID)
        guard let rawValue = try loadState().sceneRegistry[key] else { return nil }
        return .init(rawValue: rawValue)
    }

    public func saveSceneID(
        _ sceneID: HueResourceID?,
        bridgeID: String,
        areaID: HueResourceID
    ) throws {
        let key = Self.sceneKey(bridgeID: bridgeID, areaID: areaID)
        try updateState { state in
            state.sceneRegistry[key] = sceneID?.rawValue
        }
    }

    public func loadRestoreJournal() throws -> RestoreJournal? {
        _ = try loadState()
        guard let data = defaults.data(forKey: Key.recoveryV2) else { return nil }
        return try decodeEnvelope(
            RestoreJournal.self,
            from: data,
            key: Key.recoveryV2
        )
    }

    public func saveRestoreJournal(_ journal: RestoreJournal?) throws {
        _ = try loadState()
        if let journal {
            defaults.set(try encodeEnvelope(journal), forKey: Key.recoveryV2)
        } else {
            defaults.removeObject(forKey: Key.recoveryV2)
        }
    }

    public func loadLiveDescriptor() throws -> LiveSessionDescriptor? {
        try loadState().liveDescriptor
    }

    public func saveLiveDescriptor(_ descriptor: LiveSessionDescriptor?) throws {
        try updateState { $0.liveDescriptor = descriptor }
    }

    public func loadLiveStatus() throws -> LiveSessionStatus {
        try loadState().liveStatus
    }

    public func saveLiveStatus(_ status: LiveSessionStatus) throws {
        try updateState { $0.liveStatus = status }
    }

    public func clearBridgeState(
        bridgeID: String,
        discardRecovery: Bool = false
    ) throws {
        let removesRecovery: Bool
        if let journal = try loadRestoreJournal(), journal.bridgeID == bridgeID {
            guard discardRecovery else {
                throw PersistenceError.recoveryRequired(bridgeID)
            }
            removesRecovery = true
        } else {
            removesRecovery = false
        }

        try updateState { state in
            state.profiles.removeValue(forKey: bridgeID)
            if state.activeBridgeID == bridgeID { state.activeBridgeID = nil }
            state.selectedAreaIDs.removeValue(forKey: bridgeID)
            state.sceneRegistry = state.sceneRegistry.filter {
                !$0.key.hasPrefix("\(bridgeID)/")
            }
            if state.liveDescriptor?.profile.bridgeID == bridgeID {
                state.liveDescriptor = nil
                state.liveStatus = .idle
            }
        }
        if removesRecovery {
            defaults.removeObject(forKey: Key.recoveryV2)
        }
    }

    public func migrationReport() -> PersistenceMigrationReport? {
        guard let data = defaults.data(forKey: Key.migrationReportV2) else { return nil }
        return try? decoder().decode(PersistenceMigrationReport.self, from: data)
    }

    public func quarantinedRecords() -> [PersistenceQuarantineRecord] {
        guard let data = defaults.data(forKey: Key.quarantineV2) else { return [] }
        return (try? decoder().decode([PersistenceQuarantineRecord].self, from: data)) ?? []
    }

    public func hasLegacyBackup() -> Bool {
        defaults.data(forKey: Key.legacyBackupV1) != nil
    }

    public func rollbackToLegacyBackup() throws {
        guard let data = defaults.data(forKey: Key.legacyBackupV1) else {
            throw PersistenceError.missingLegacyBackup
        }
        let backup = try decoder().decode(LegacyPersistenceBackup.self, from: data)
        restoreLegacyValue(backup.profile, forKey: Key.legacyProfile)
        restoreLegacyDictionaryData(backup.selectedAreas, forKey: Key.legacySelectedArea)
        restoreLegacyDictionaryData(backup.sceneRegistry, forKey: Key.legacySceneRegistry)
        restoreLegacyValue(backup.restoreJournal, forKey: Key.legacyRestoreJournal)
        restoreLegacyValue(backup.liveDescriptor, forKey: Key.legacyLiveDescriptor)
        restoreLegacyValue(backup.liveStatus, forKey: Key.legacyLiveStatus)

        defaults.removeObject(forKey: Key.stateV2)
        defaults.removeObject(forKey: Key.recoveryV2)
        defaults.removeObject(forKey: Key.migrationReportV2)
        cachedState = nil
    }

    private func loadState() throws -> NativeAppState {
        if let cachedState { return cachedState }
        if let data = defaults.data(forKey: Key.stateV2) {
            let state = try decodeEnvelope(NativeAppState.self, from: data, key: Key.stateV2)
            cachedState = state
            return state
        }
        return try migrateLegacyState()
    }

    private func updateState(_ mutation: (inout NativeAppState) throws -> Void) throws {
        var state = try loadState()
        try mutation(&state)
        try writeState(state)
    }

    private func writeState(_ state: NativeAppState) throws {
        defaults.set(try encodeEnvelope(state), forKey: Key.stateV2)
        cachedState = state
    }

    private func migrateLegacyState() throws -> NativeAppState {
        let startedAt = Date()
        let backup = LegacyPersistenceBackup(
            capturedAt: startedAt,
            profile: defaults.data(forKey: Key.legacyProfile),
            selectedAreas: legacyDictionaryData(forKey: Key.legacySelectedArea),
            sceneRegistry: legacyDictionaryData(forKey: Key.legacySceneRegistry),
            restoreJournal: defaults.data(forKey: Key.legacyRestoreJournal),
            liveDescriptor: defaults.data(forKey: Key.legacyLiveDescriptor),
            liveStatus: defaults.data(forKey: Key.legacyLiveStatus)
        )

        let backupCreated: Bool
        if backup.containsData, defaults.data(forKey: Key.legacyBackupV1) == nil {
            defaults.set(try encoder().encode(backup), forKey: Key.legacyBackupV1)
            backupCreated = true
        } else {
            backupCreated = false
        }

        var migratedKeys: [String] = []
        var quarantinedKeys: [String] = []
        let profile: BridgeProfile? = decodeLegacy(
            BridgeProfile.self,
            data: backup.profile,
            key: Key.legacyProfile,
            migratedKeys: &migratedKeys,
            quarantinedKeys: &quarantinedKeys
        )
        let liveDescriptor: LiveSessionDescriptor? = decodeLegacy(
            LiveSessionDescriptor.self,
            data: backup.liveDescriptor,
            key: Key.legacyLiveDescriptor,
            migratedKeys: &migratedKeys,
            quarantinedKeys: &quarantinedKeys
        )
        let liveStatus: LiveSessionStatus? = decodeLegacy(
            LiveSessionStatus.self,
            data: backup.liveStatus,
            key: Key.legacyLiveStatus,
            migratedKeys: &migratedKeys,
            quarantinedKeys: &quarantinedKeys
        )

        let selectedAreas = decodeLegacyStringDictionary(
            data: backup.selectedAreas,
            key: Key.legacySelectedArea,
            migratedKeys: &migratedKeys,
            quarantinedKeys: &quarantinedKeys
        )
        let sceneRegistry = decodeLegacyStringDictionary(
            data: backup.sceneRegistry,
            key: Key.legacySceneRegistry,
            migratedKeys: &migratedKeys,
            quarantinedKeys: &quarantinedKeys
        )

        let state = NativeAppState(
            profiles: profile.map { [$0.bridgeID: $0] } ?? [:],
            activeBridgeID: profile?.bridgeID,
            selectedAreaIDs: selectedAreas,
            sceneRegistry: sceneRegistry,
            liveDescriptor: liveDescriptor,
            liveStatus: liveStatus ?? .idle
        )
        try writeState(state)

        if let journal: RestoreJournal = decodeLegacy(
            RestoreJournal.self,
            data: backup.restoreJournal,
            key: Key.legacyRestoreJournal,
            migratedKeys: &migratedKeys,
            quarantinedKeys: &quarantinedKeys
        ) {
            defaults.set(try encodeEnvelope(journal), forKey: Key.recoveryV2)
        }

        let report = PersistenceMigrationReport(
            sourceSchema: backup.containsData ? 1 : nil,
            targetSchema: NativePersistenceVersion.currentSchema,
            startedAt: startedAt,
            completedAt: Date(),
            migratedKeys: migratedKeys.sorted(),
            quarantinedKeys: quarantinedKeys.sorted(),
            legacyBackupCreated: backupCreated
        )
        defaults.set(try encoder().encode(report), forKey: Key.migrationReportV2)
        return state
    }

    private func decodeLegacy<Value: Decodable>(
        _ type: Value.Type,
        data: Data?,
        key: String,
        migratedKeys: inout [String],
        quarantinedKeys: inout [String]
    ) -> Value? {
        guard let data else { return nil }
        do {
            let value = try decoder().decode(type, from: data)
            migratedKeys.append(key)
            return value
        } catch {
            quarantine(data, key: key, reason: error.localizedDescription)
            quarantinedKeys.append(key)
            return nil
        }
    }

    private func encodeEnvelope<Value: Codable & Sendable>(_ value: Value) throws -> Data {
        let payloadData = try encoder().encode(value)
        let envelope = PersistenceEnvelope(
            schemaVersion: NativePersistenceVersion.currentSchema,
            writtenByVersion: writerVersion,
            writtenAt: Date(),
            payloadSHA256: PersistenceChecksum.sha256Hex(payloadData),
            payload: value
        )
        return try encoder().encode(envelope)
    }

    private func decodeEnvelope<Value: Codable & Sendable>(
        _ type: Value.Type,
        from data: Data,
        key: String
    ) throws -> Value {
        let envelope: PersistenceEnvelope<Value>
        do {
            envelope = try decoder().decode(PersistenceEnvelope<Value>.self, from: data)
        } catch {
            quarantine(data, key: key, reason: error.localizedDescription)
            throw PersistenceError.corruptRecord(key)
        }
        guard envelope.schemaVersion == NativePersistenceVersion.currentSchema else {
            throw PersistenceError.unsupportedSchema(envelope.schemaVersion)
        }
        let payloadData = try encoder().encode(envelope.payload)
        let digest = PersistenceChecksum.sha256Hex(payloadData)
        guard digest == envelope.payloadSHA256 else {
            quarantine(data, key: key, reason: "SHA-256 mismatch")
            throw PersistenceError.checksumMismatch(key)
        }
        return envelope.payload
    }

    private func quarantine(_ data: Data, key: String, reason: String) {
        var records = quarantinedRecords()
        records.append(
            PersistenceQuarantineRecord(key: key, rawData: data, reason: reason)
        )
        if let encoded = try? encoder().encode(records) {
            defaults.set(encoded, forKey: Key.quarantineV2)
        }
    }

    private func legacyDictionaryData(forKey key: String) -> Data? {
        guard let value = defaults.dictionary(forKey: key) else { return nil }
        return try? PropertyListSerialization.data(
            fromPropertyList: value,
            format: .binary,
            options: 0
        )
    }

    private func decodeLegacyStringDictionary(
        data: Data?,
        key: String,
        migratedKeys: inout [String],
        quarantinedKeys: inout [String]
    ) -> [String: String] {
        guard let data else { return [:] }
        do {
            let propertyList = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
            guard let raw = propertyList as? [String: Any] else {
                throw PersistenceError.corruptRecord(key)
            }
            let values = raw.compactMapValues { $0 as? String }
            if raw.count != values.count {
                quarantine(data, key: key, reason: "Discarded non-string dictionary values")
                quarantinedKeys.append(key)
            }
            if !values.isEmpty { migratedKeys.append(key) }
            return values
        } catch {
            quarantine(data, key: key, reason: error.localizedDescription)
            quarantinedKeys.append(key)
            return [:]
        }
    }

    private func restoreLegacyValue(_ data: Data?, forKey key: String) {
        if let data { defaults.set(data, forKey: key) }
        else { defaults.removeObject(forKey: key) }
    }

    private func restoreLegacyDictionaryData(_ data: Data?, forKey key: String) {
        guard let data,
              let value = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              )
        else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(value, forKey: key)
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func sceneKey(bridgeID: String, areaID: HueResourceID) -> String {
        "\(bridgeID)/\(areaID.rawValue)"
    }
}
