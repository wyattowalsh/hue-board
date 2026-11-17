import Foundation
import HueBoardKit

private actor HueLightFrameWriter {
    private let kind: LightingTransportKind
    private let client: any HueLightUpdateSending
    private let profile: BridgeProfile
    private let credential: HueBridgeCredential
    private let allowedLightIDs: Set<HueResourceID>
    private var activeLease: PlaybackWriterLease?
    private var inFlightWrites = 0
    private var writeIdleWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        kind: LightingTransportKind,
        client: any HueLightUpdateSending,
        profile: BridgeProfile,
        credential: HueBridgeCredential,
        allowedLightIDs: Set<HueResourceID>
    ) {
        self.kind = kind
        self.client = client
        self.profile = profile
        self.credential = credential
        self.allowedLightIDs = allowedLightIDs
    }

    func prepare(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) throws {
        guard request.transport == kind, lease.transport == kind else {
            throw PlaybackCoordinationError.transportMismatch(
                expected: kind,
                actual: request.transport
            )
        }
        guard request.scope == lease.scope,
              request.scope.bridgeID == profile.bridgeID
        else {
            throw PlaybackCoordinationError.staleLease(lease)
        }
        guard !allowedLightIDs.isEmpty else {
            throw HueBoardError.unsupported("No eligible lights are available for this operation.")
        }
    }

    func start(lease: PlaybackWriterLease) throws {
        if let activeLease {
            throw PlaybackCoordinationError.busy(activeLease)
        }
        self.activeLease = lease
    }

    func submit(_ frame: LightingFrame, lease: PlaybackWriterLease) async throws {
        guard activeLease == lease else {
            throw PlaybackCoordinationError.staleLease(lease)
        }
        let unexpected = Set(frame.actions.keys).subtracting(allowedLightIDs)
        guard unexpected.isEmpty else {
            throw HueBoardError.unsupported(
                "The operation attempted to address lights outside its prepared scope."
            )
        }
        for id in frame.actions.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard activeLease == lease else {
                throw PlaybackCoordinationError.staleLease(lease)
            }
            guard let action = frame.actions[id] else { continue }
            inFlightWrites += 1
            defer { completeInFlightWrite() }
            try await client.updateLight(
                id: id,
                action: action,
                profile: profile,
                credential: credential
            )
            guard activeLease == lease else {
                throw PlaybackCoordinationError.staleLease(lease)
            }
        }
    }

    func stop(lease: PlaybackWriterLease) async {
        if activeLease == lease {
            activeLease = nil
        }
        await waitForInFlightWrites()
    }

    private func completeInFlightWrite() {
        inFlightWrites -= 1
        guard inFlightWrites == 0 else { return }
        let waiters = writeIdleWaiters
        writeIdleWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func waitForInFlightWrites() async {
        guard inFlightWrites > 0 else { return }
        await withCheckedContinuation { writeIdleWaiters.append($0) }
    }
}

public actor DirectControlTransport: LightingTransport {
    public nonisolated let kind: LightingTransportKind = .directControl
    public nonisolated let capabilities = LightingTransportCapabilities(
        performsPhysicalWrites: true,
        continuesWithoutAppExecution: false,
        supportsFrameSubmission: true,
        supportsHighRateFrames: false
    )
    private let writer: HueLightFrameWriter

    public init(
        client: any HueLightUpdateSending,
        profile: BridgeProfile,
        credential: HueBridgeCredential,
        allowedLightIDs: Set<HueResourceID>
    ) {
        writer = .init(
            kind: .directControl,
            client: client,
            profile: profile,
            credential: credential,
            allowedLightIDs: allowedLightIDs
        )
    }

    public func prepare(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws {
        try await writer.prepare(request, lease: lease)
    }

    public func start(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws {
        try await writer.start(lease: lease)
    }

    public func submit(
        _ frame: LightingFrame,
        lease: PlaybackWriterLease
    ) async throws {
        try await writer.submit(frame, lease: lease)
    }

    public func stop(
        lease: PlaybackWriterLease,
        reason: PlaybackStopReason
    ) async {
        await writer.stop(lease: lease)
    }
}

public actor RestAmbientTransport: LightingTransport {
    public nonisolated let kind: LightingTransportKind = .restAmbient
    public nonisolated let capabilities = LightingTransportCapabilities(
        performsPhysicalWrites: true,
        continuesWithoutAppExecution: false,
        supportsFrameSubmission: true,
        supportsHighRateFrames: false
    )
    private let writer: HueLightFrameWriter

    public init(
        client: any HueLightUpdateSending,
        profile: BridgeProfile,
        credential: HueBridgeCredential,
        allowedLightIDs: Set<HueResourceID>
    ) {
        writer = .init(
            kind: .restAmbient,
            client: client,
            profile: profile,
            credential: credential,
            allowedLightIDs: allowedLightIDs
        )
    }

    public func prepare(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws {
        try await writer.prepare(request, lease: lease)
    }

    public func start(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws {
        try await writer.start(lease: lease)
    }

    public func submit(
        _ frame: LightingFrame,
        lease: PlaybackWriterLease
    ) async throws {
        for action in frame.actions.values {
            let duration = action.dynamics?.duration ?? 0
            guard duration >= 4_500 else {
                throw HueBoardError.unsupported(
                    "Ambient Live transitions must last at least 4.5 seconds."
                )
            }
        }
        try await writer.submit(frame, lease: lease)
    }

    public func stop(
        lease: PlaybackWriterLease,
        reason: PlaybackStopReason
    ) async {
        await writer.stop(lease: lease)
    }
}
