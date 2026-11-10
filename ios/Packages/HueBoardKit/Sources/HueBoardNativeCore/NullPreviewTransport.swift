import Foundation
import HueBoardKit

public actor NullPreviewTransport: LightingTransport {
    public nonisolated let kind: LightingTransportKind = .preview
    public nonisolated let capabilities = LightingTransportCapabilities(
        performsPhysicalWrites: false,
        continuesWithoutAppExecution: false,
        supportsFrameSubmission: true,
        supportsHighRateFrames: true
    )

    private var activeLease: PlaybackWriterLease?
    private var capturedFrames: [LightingFrame] = []

    public init() {}

    public func prepare(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws {
        guard request.transport == .preview else {
            throw PlaybackCoordinationError.transportMismatch(
                expected: .preview,
                actual: request.transport
            )
        }
        guard request.scope == lease.scope else {
            throw PlaybackCoordinationError.staleLease(lease)
        }
    }

    public func start(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws {
        guard activeLease == nil else {
            throw PlaybackCoordinationError.busy(activeLease!)
        }
        activeLease = lease
        capturedFrames.removeAll(keepingCapacity: true)
    }

    public func submit(
        _ frame: LightingFrame,
        lease: PlaybackWriterLease
    ) async throws {
        guard activeLease == lease else {
            throw PlaybackCoordinationError.staleLease(lease)
        }
        capturedFrames.append(frame)
    }

    public func stop(
        lease: PlaybackWriterLease,
        reason: PlaybackStopReason
    ) async {
        if activeLease == lease {
            activeLease = nil
        }
    }

    public func frames() -> [LightingFrame] {
        capturedFrames
    }

    public func isActive() -> Bool {
        activeLease != nil
    }
}
