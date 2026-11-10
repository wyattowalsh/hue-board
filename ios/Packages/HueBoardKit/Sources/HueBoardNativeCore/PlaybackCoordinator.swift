import Foundation
import HueBoardKit

public actor PlaybackCoordinator {
    private struct ActiveWriter: Sendable {
        let lease: PlaybackWriterLease
        let transport: any LightingTransport
    }

    private var epoch: UInt64 = 0
    private var active: ActiveWriter?

    public init() {}

    public func begin(
        _ request: LightingPlaybackRequest,
        using transport: any LightingTransport,
        at date: Date = Date()
    ) async throws -> PlaybackWriterLease {
        guard transport.kind == request.transport else {
            throw PlaybackCoordinationError.transportMismatch(
                expected: request.transport,
                actual: transport.kind
            )
        }
        if let active {
            throw PlaybackCoordinationError.busy(active.lease)
        }

        epoch &+= 1
        let lease = PlaybackWriterLease(
            operationID: .init(),
            epoch: .init(rawValue: epoch),
            scope: request.scope,
            transport: request.transport,
            startedAt: date
        )
        active = .init(lease: lease, transport: transport)

        do {
            try await transport.prepare(request, lease: lease)
            _ = try requireCurrent(lease)
            try await transport.start(request, lease: lease)
            _ = try requireCurrent(lease)
            return lease
        } catch {
            guard active?.lease == lease else {
                throw PlaybackCoordinationError.staleLease(lease)
            }
            active = nil
            epoch &+= 1
            await transport.stop(lease: lease, reason: .failed)
            throw error
        }
    }

    public func submit(_ frame: LightingFrame, lease: PlaybackWriterLease) async throws {
        let current = try requireCurrent(lease)
        guard current.transport.capabilities.supportsFrameSubmission else {
            throw PlaybackCoordinationError.frameSubmissionUnsupported(current.transport.kind)
        }
        try await current.transport.submit(frame, lease: lease)
        _ = try requireCurrent(lease)
    }

    public func finish(_ lease: PlaybackWriterLease) async throws {
        let current = try requireCurrent(lease)
        active = nil
        epoch &+= 1
        await current.transport.stop(lease: lease, reason: .completed)
    }

    public func stopCurrent(reason: PlaybackStopReason) async -> PlaybackWriterLease? {
        guard let current = active else { return nil }
        active = nil
        epoch &+= 1
        await current.transport.stop(lease: current.lease, reason: reason)
        return current.lease
    }

    public func currentLease() -> PlaybackWriterLease? {
        active?.lease
    }

    public func isCurrent(_ lease: PlaybackWriterLease) -> Bool {
        active?.lease == lease
    }

    public func assertCurrent(_ lease: PlaybackWriterLease) throws {
        _ = try requireCurrent(lease)
    }

    private func requireCurrent(_ lease: PlaybackWriterLease) throws -> ActiveWriter {
        guard let active, active.lease == lease else {
            throw PlaybackCoordinationError.staleLease(lease)
        }
        return active
    }
}
