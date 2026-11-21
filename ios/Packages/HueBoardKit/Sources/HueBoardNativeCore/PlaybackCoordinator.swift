import Foundation
import HueBoardKit

public actor PlaybackCoordinator {
    private struct ActiveWriter: Sendable {
        let lease: PlaybackWriterLease
        let transport: any LightingTransport
    }

    private var epoch: UInt64 = 0
    private var active: ActiveWriter?
    private var draining: ActiveWriter?
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []

    #if DEBUG
    public private(set) var debugWriterAcquisitions: UInt64 = 0
    #endif

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
        if let writer = active ?? draining {
            throw PlaybackCoordinationError.busy(writer.lease)
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
        #if DEBUG
        debugWriterAcquisitions &+= 1
        #endif

        do {
            try await transport.prepare(request, lease: lease)
            _ = try requireCurrent(lease)
            try await transport.start(request, lease: lease)
            _ = try requireCurrent(lease)
            return lease
        } catch {
            guard let current = active, current.lease == lease else {
                throw PlaybackCoordinationError.staleLease(lease)
            }
            await retire(current, reason: .failed)
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
        await retire(current, reason: .completed)
    }

    public func stopCurrent(
        reason: PlaybackStopReason,
        matching expectedLease: PlaybackWriterLease? = nil
    ) async -> PlaybackWriterLease? {
        guard let current = active else {
            if let draining, expectedLease == nil || draining.lease == expectedLease {
                await withCheckedContinuation { drainWaiters.append($0) }
            }
            return nil
        }
        guard expectedLease == nil || current.lease == expectedLease else { return nil }
        await retire(current, reason: reason)
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

    private func retire(_ writer: ActiveWriter, reason: PlaybackStopReason) async {
        // Reject stale frames immediately and hold the writer slot until its
        // in-flight requests return, including during a concurrent stop.
        active = nil
        draining = writer
        epoch &+= 1
        await writer.transport.stop(lease: writer.lease, reason: reason)
        draining = nil
        let waiters = drainWaiters
        drainWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func requireCurrent(_ lease: PlaybackWriterLease) throws -> ActiveWriter {
        guard let active, active.lease == lease else {
            throw PlaybackCoordinationError.staleLease(lease)
        }
        return active
    }
}
