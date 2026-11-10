import Foundation
import XCTest
import HueBoardKit
@testable import HueBoardNativeCore

final class PlaybackCoordinatorTests: XCTestCase {
    private let scope = LightingScope(
        bridgeID: "001788fffe123456",
        areaID: .init(rawValue: "room-one")
    )

    func testOnlyOneWriterCanOwnCoordinator() async throws {
        let coordinator = PlaybackCoordinator()
        let firstTransport = NullPreviewTransport()
        let secondTransport = NullPreviewTransport()
        let request = previewRequest()
        let first = try await coordinator.begin(request, using: firstTransport)

        do {
            _ = try await coordinator.begin(request, using: secondTransport)
            XCTFail("A second writer must not start")
        } catch PlaybackCoordinationError.busy(let active) {
            XCTAssertEqual(active, first)
        }
        let current = await coordinator.currentLease()
        XCTAssertEqual(current, first)
        try await coordinator.finish(first)
        let finished = await coordinator.currentLease()
        XCTAssertNil(finished)
    }

    func testStoppingInvalidatesLeaseAndRejectsLateFrames() async throws {
        let coordinator = PlaybackCoordinator()
        let transport = NullPreviewTransport()
        let lease = try await coordinator.begin(previewRequest(), using: transport)
        _ = await coordinator.stopCurrent(reason: .cancelled)

        do {
            try await coordinator.submit(frame(sequence: 1), lease: lease)
            XCTFail("A stale lease must not submit")
        } catch PlaybackCoordinationError.staleLease(let stale) {
            XCTAssertEqual(stale, lease)
        }
        let isActive = await transport.isActive()
        XCTAssertFalse(isActive)
    }

    func testNullPreviewCapturesFramesWithoutPhysicalWriteCapability() async throws {
        let coordinator = PlaybackCoordinator()
        let transport = NullPreviewTransport()
        XCTAssertFalse(transport.capabilities.performsPhysicalWrites)
        let lease = try await coordinator.begin(previewRequest(), using: transport)
        try await coordinator.submit(frame(sequence: 1), lease: lease)
        try await coordinator.submit(frame(sequence: 2), lease: lease)
        let sequences = await transport.frames().map(\.sequence)
        XCTAssertEqual(sequences, [1, 2])
        try await coordinator.finish(lease)
    }

    func testTransportKindMismatchFailsBeforeOwnership() async throws {
        let coordinator = PlaybackCoordinator()
        let transport = NullPreviewTransport()
        let request = LightingPlaybackRequest(
            scope: scope,
            transport: .restAmbient,
            presetID: "ion-eclipse"
        )
        do {
            _ = try await coordinator.begin(request, using: transport)
            XCTFail("Mismatched transport must fail")
        } catch PlaybackCoordinationError.transportMismatch(let expected, let actual) {
            XCTAssertEqual(expected, .restAmbient)
            XCTAssertEqual(actual, .preview)
        }
        let current = await coordinator.currentLease()
        XCTAssertNil(current)
    }

    func testCancellationDuringPrepareInvalidatesLateCompletion() async throws {
        let coordinator = PlaybackCoordinator()
        let transport = SuspendedTransport()
        let request = LightingPlaybackRequest(
            scope: scope,
            transport: .restAmbient,
            presetID: "ion-eclipse"
        )

        let beginTask = Task {
            try await coordinator.begin(request, using: transport)
        }
        await transport.waitUntilPreparing()
        let stopped = await coordinator.stopCurrent(reason: .cancelled)
        XCTAssertNotNil(stopped)
        await transport.resumePreparation()

        do {
            _ = try await beginTask.value
            XCTFail("Late preparation must not restore ownership")
        } catch PlaybackCoordinationError.staleLease(let lease) {
            XCTAssertEqual(lease, stopped)
        }
        let reasons = await transport.stopReasons()
        XCTAssertEqual(reasons, [.cancelled])
        let current = await coordinator.currentLease()
        XCTAssertNil(current)
    }

    private func previewRequest() -> LightingPlaybackRequest {
        .init(scope: scope, transport: .preview, presetID: "ion-eclipse")
    }

    private func frame(sequence: UInt64) -> LightingFrame {
        .init(
            sequence: sequence,
            generatedAt: Date(timeIntervalSince1970: Double(sequence)),
            actions: [
                .init(rawValue: "light-one"): .init(
                    on: .init(on: true),
                    dimming: .init(brightness: 30)
                )
            ]
        )
    }
}

private actor SuspendedTransport: LightingTransport {
    nonisolated let kind: LightingTransportKind = .restAmbient
    nonisolated let capabilities = LightingTransportCapabilities(
        performsPhysicalWrites: true,
        continuesWithoutAppExecution: false,
        supportsFrameSubmission: true,
        supportsHighRateFrames: false
    )

    private var preparationContinuation: CheckedContinuation<Void, Never>?
    private var preparingContinuation: CheckedContinuation<Void, Never>?
    private var preparing = false
    private var reasons: [PlaybackStopReason] = []

    func prepare(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws {
        preparing = true
        preparingContinuation?.resume()
        preparingContinuation = nil
        await withCheckedContinuation { continuation in
            preparationContinuation = continuation
        }
    }

    func start(
        _ request: LightingPlaybackRequest,
        lease: PlaybackWriterLease
    ) async throws {}

    func submit(
        _ frame: LightingFrame,
        lease: PlaybackWriterLease
    ) async throws {}

    func stop(
        lease: PlaybackWriterLease,
        reason: PlaybackStopReason
    ) async {
        reasons.append(reason)
    }

    func waitUntilPreparing() async {
        if preparing { return }
        await withCheckedContinuation { continuation in
            preparingContinuation = continuation
        }
    }

    func resumePreparation() {
        preparationContinuation?.resume()
        preparationContinuation = nil
    }

    func stopReasons() -> [PlaybackStopReason] {
        reasons
    }
}
