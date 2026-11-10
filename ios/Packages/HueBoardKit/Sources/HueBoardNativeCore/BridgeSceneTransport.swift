import Foundation
import HueBoardKit

public enum BridgeSceneOutcome: Equatable, Sendable {
    case idle
    case prepared(existingSceneID: HueResourceID?)
    case accepted(sceneID: HueResourceID)
    case uncertain(sceneID: HueResourceID?, message: String)
}

public actor BridgeSceneTransport: LightingTransport {
    public nonisolated let kind: LightingTransportKind = .bridgeScene
    public nonisolated let capabilities = LightingTransportCapabilities(
        performsPhysicalWrites: true,
        continuesWithoutAppExecution: true,
        supportsFrameSubmission: false,
        supportsHighRateFrames: false
    )

    private struct PreparedPlan: Sendable {
        let draft: HueSceneDraft
        let existingSceneID: HueResourceID?
    }

    private let client: any HueBridgePlaybackClient
    private let persistence: AppPersistence
    private let profile: BridgeProfile
    private let credential: HueBridgeCredential
    private let contract: HueBoardContract
    private let preset: HuePreset
    private let brightness: Double
    private var plan: PreparedPlan?
    private var activeLease: PlaybackWriterLease?
    private var currentOutcome: BridgeSceneOutcome = .idle

    public init(
        client: any HueBridgePlaybackClient,
        persistence: AppPersistence,
        profile: BridgeProfile,
        credential: HueBridgeCredential,
        contract: HueBoardContract,
        preset: HuePreset,
        brightness: Double
    ) {
        self.client = client
        self.persistence = persistence
        self.profile = profile
        self.credential = credential
        self.contract = contract
        self.preset = preset
        self.brightness = brightness
    }

    public func prepare(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws {
        guard request.transport == .bridgeScene else {
            throw PlaybackCoordinationError.transportMismatch(
                expected: .bridgeScene,
                actual: request.transport
            )
        }
        guard request.scope == lease.scope,
              request.scope.bridgeID == profile.bridgeID,
              request.presetID == preset.id
        else {
            throw PlaybackCoordinationError.staleLease(lease)
        }

        let areas = try await client.inventory(
            profile: profile,
            credential: credential,
            outputLimits: [:]
        )
        guard let area = areas.first(where: { $0.id == request.scope.areaID }) else {
            throw HueBoardError.missingResource("The selected area is no longer available.")
        }
        let draft = try HueSceneBuilder.build(
            area: area,
            preset: preset,
            contract: contract,
            brightness: brightness
        )

        var existingSceneID = try await persistence.sceneID(
            bridgeID: profile.bridgeID,
            areaID: area.id
        )
        if let id = existingSceneID {
            let scene = try await client.sceneIfPresent(
                id: id,
                profile: profile,
                credential: credential
            )
            if scene?.group?.resourceID != area.id
                || scene?.group?.resourceType != area.kind.rawValue
            {
                try await persistence.saveSceneID(
                    nil,
                    bridgeID: profile.bridgeID,
                    areaID: area.id
                )
                existingSceneID = nil
            }
        }

        try await ensureRestoreJournal(
            area: area,
            touchedIDs: Set(draft.animatedLightIDs)
        )
        plan = .init(draft: draft, existingSceneID: existingSceneID)
        currentOutcome = .prepared(existingSceneID: existingSceneID)
    }

    public func start(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws {
        guard activeLease == nil, let plan else {
            throw HueBoardError.invalidResponse("Bridge scene playback was not prepared.")
        }
        activeLease = lease
        var sceneID = plan.existingSceneID
        var mutationAttempted = false
        var recallAttempted = false

        do {
            try requireActive(lease)
            if let existing = sceneID {
                mutationAttempted = true
                try await client.updateScene(
                    id: existing,
                    scene: plan.draft.update,
                    profile: profile,
                    credential: credential
                )
                try requireActive(lease)
            } else {
                mutationAttempted = true
                sceneID = try await client.createScene(
                    plan.draft.create,
                    profile: profile,
                    credential: credential
                )
                try requireActive(lease)
                if let sceneID {
                    try await persistence.saveSceneID(
                        sceneID,
                        bridgeID: profile.bridgeID,
                        areaID: request.scope.areaID
                    )
                    try requireActive(lease)
                }
            }
            guard let sceneID else {
                throw HueBoardError.invalidResponse("Bridge returned no scene identifier.")
            }
            try requireActive(lease)
            recallAttempted = true
            try await client.recallScene(
                id: sceneID,
                profile: profile,
                credential: credential
            )
            try requireActive(lease)
            currentOutcome = .accepted(sceneID: sceneID)
        } catch {
            guard mutationAttempted else {
                activeLease = nil
                throw error
            }
            let stage = recallAttempted ? "recall" : "preparation"
            currentOutcome = .uncertain(
                sceneID: sceneID,
                message:
                    "Bridge scene \(stage) is uncertain: \(error.localizedDescription) Stop and restore before retrying."
            )
        }
    }

    public func submit(
        _ frame: LightingFrame,
        lease: PlaybackWriterLease
    ) async throws {
        throw PlaybackCoordinationError.frameSubmissionUnsupported(.bridgeScene)
    }

    public func stop(
        lease: PlaybackWriterLease,
        reason: PlaybackStopReason
    ) async {
        if activeLease == lease {
            activeLease = nil
            plan = nil
        }
    }

    public func outcome() -> BridgeSceneOutcome {
        currentOutcome
    }

    private func requireActive(_ lease: PlaybackWriterLease) throws {
        guard activeLease == lease else {
            throw PlaybackCoordinationError.staleLease(lease)
        }
    }

    private func ensureRestoreJournal(
        area: HueArea,
        touchedIDs: Set<HueResourceID>
    ) async throws {
        let touched = area.lights.filter { touchedIDs.contains($0.id) }
        guard !touched.isEmpty else {
            throw HueBoardError.unsupported("No compatible lights are selected.")
        }
        if var existing = try await persistence.loadRestoreJournal() {
            guard existing.bridgeID == profile.bridgeID, existing.areaID == area.id else {
                throw HueBoardError.unsupported(
                    "Restore the previous area before starting new playback."
                )
            }
            if try existing.captureMissing(from: area, touchedIDs: touchedIDs) > 0 {
                try await persistence.saveRestoreJournal(existing)
            }
            return
        }
        try await persistence.saveRestoreJournal(
            RestoreJournal(bridgeID: profile.bridgeID, area: area, lights: touched)
        )
    }
}
