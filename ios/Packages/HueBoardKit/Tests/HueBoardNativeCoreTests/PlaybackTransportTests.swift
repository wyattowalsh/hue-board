import Foundation
import XCTest
import HueBoardKit
@testable import HueBoardNativeCore

final class PlaybackTransportTests: XCTestCase {
    private let bridgeID = "001788fffe123456"
    private let fingerprint = String(repeating: "ab", count: 32)

    func testDirectControlWritesInStableOrderAndRejectsUnpreparedIDs() async throws {
        let client = FakePlaybackClient(areas: [])
        let profile = try makeProfile()
        let credential = HueBridgeCredential(bridgeID: bridgeID, applicationKey: "test-key")
        let transport = DirectControlTransport(
            client: client,
            profile: profile,
            credential: credential,
            allowedLightIDs: [id("a"), id("b")]
        )
        let coordinator = PlaybackCoordinator()
        let request = LightingPlaybackRequest(
            scope: .init(bridgeID: bridgeID, areaID: id("room")),
            transport: .directControl,
            presetID: "test"
        )
        let lease = try await coordinator.begin(request, using: transport)
        try await coordinator.submit(
            .init(
                sequence: 1,
                actions: [
                    id("b"): .init(on: .init(on: false)),
                    id("a"): .init(on: .init(on: true)),
                ]
            ),
            lease: lease
        )
        let writeIDs = await client.lightWriteIDs()
        XCTAssertEqual(writeIDs, [id("a"), id("b")])

        do {
            try await coordinator.submit(
                .init(sequence: 2, actions: [id("outside"): .init(on: .init(on: true))]),
                lease: lease
            )
            XCTFail("An unprepared light must be rejected")
        } catch let error as HueBoardError {
            guard case .unsupported = error else {
                return XCTFail("Expected unsupported scope error, got \(error)")
            }
        }
        try await coordinator.finish(lease)
    }

    func testBridgeSceneCapturesRecoveryBeforeCreateAndRecall() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let persistence = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        let area = makeArea()
        let client = FakePlaybackClient(
            areas: [area],
            persistence: persistence,
            expectedJournalScope: .init(bridgeID: bridgeID, areaID: area.id)
        )
        let transport = try makeBridgeTransport(client: client, persistence: persistence)
        let coordinator = PlaybackCoordinator()
        let lease = try await coordinator.begin(bridgeRequest(area: area), using: transport)

        guard case .accepted(let sceneID) = await transport.outcome() else {
            return XCTFail("Bridge scene should be accepted")
        }
        XCTAssertEqual(sceneID, id("created-scene"))
        let acceptedEvents = await client.events()
        XCTAssertEqual(acceptedEvents, ["inventory", "create", "recall"])
        let journal = try await persistence.loadRestoreJournal()
        XCTAssertEqual(journal?.bridgeID, bridgeID)
        XCTAssertEqual(journal?.areaID, area.id)
        XCTAssertEqual(journal?.capturedLightIDs, Set(area.lights.map(\.id)))
        let acceptedLeaseIsCurrent = await coordinator.isCurrent(lease)
        XCTAssertTrue(acceptedLeaseIsCurrent)
        _ = await coordinator.stopCurrent(reason: .recovery)
    }

    func testBridgeRecallFailureStaysOwnedAndUncertain() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let persistence = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        let area = makeArea()
        let client = FakePlaybackClient(
            areas: [area],
            persistence: persistence,
            expectedJournalScope: .init(bridgeID: bridgeID, areaID: area.id),
            failRecall: true
        )
        let transport = try makeBridgeTransport(client: client, persistence: persistence)
        let coordinator = PlaybackCoordinator()
        let lease = try await coordinator.begin(bridgeRequest(area: area), using: transport)

        guard case .uncertain(let sceneID, let message) = await transport.outcome() else {
            return XCTFail("Lost recall acknowledgement must remain uncertain")
        }
        XCTAssertEqual(sceneID, id("created-scene"))
        XCTAssertTrue(message.contains("recall is uncertain"))
        let uncertainLeaseIsCurrent = await coordinator.isCurrent(lease)
        let retainedJournal = try await persistence.loadRestoreJournal()
        XCTAssertTrue(uncertainLeaseIsCurrent)
        XCTAssertNotNil(retainedJournal)
        _ = await coordinator.stopCurrent(reason: .recovery)
    }

    func testStaleSceneForAnotherAreaIsReplacedWithoutUpdatingIt() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let persistence = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        let area = makeArea()
        try await persistence.saveSceneID(
            id("stale-scene"),
            bridgeID: bridgeID,
            areaID: area.id
        )
        let wrongScene = try JSONDecoder().decode(
            HueSceneResource.self,
            from: Data(
                #"{"id":"stale-scene","group":{"rid":"other-room","rtype":"room"},"metadata":null}"#.utf8
            )
        )
        let client = FakePlaybackClient(
            areas: [area],
            existingScene: wrongScene,
            persistence: persistence,
            expectedJournalScope: .init(bridgeID: bridgeID, areaID: area.id)
        )
        let transport = try makeBridgeTransport(client: client, persistence: persistence)
        let coordinator = PlaybackCoordinator()
        let lease = try await coordinator.begin(bridgeRequest(area: area), using: transport)

        let replacementEvents = await client.events()
        let savedSceneID = try await persistence.sceneID(bridgeID: bridgeID, areaID: area.id)
        XCTAssertEqual(replacementEvents, ["inventory", "lookup", "create", "recall"])
        XCTAssertEqual(savedSceneID, id("created-scene"))
        _ = await coordinator.stopCurrent(reason: .recovery)
        let staleLeaseIsCurrent = await coordinator.isCurrent(lease)
        XCTAssertFalse(staleLeaseIsCurrent)
    }


    func testStoppingDuringFirstDirectWritePreventsLaterWrites() async throws {
        let client = SuspendingLightClient()
        let profile = try makeProfile()
        let transport = DirectControlTransport(
            client: client,
            profile: profile,
            credential: .init(bridgeID: bridgeID, applicationKey: "test-key"),
            allowedLightIDs: [id("a"), id("b")]
        )
        let coordinator = PlaybackCoordinator()
        let lease = try await coordinator.begin(
            .init(
                scope: .init(bridgeID: bridgeID, areaID: id("room")),
                transport: .directControl,
                presetID: "test"
            ),
            using: transport
        )
        let firstID = id("a")
        let secondID = id("b")
        let frame = LightingFrame(
            sequence: 1,
            actions: [
                firstID: .init(on: .init(on: true)),
                secondID: .init(on: .init(on: true)),
            ]
        )
        let submission = Task { [coordinator, lease, frame] in
            try await coordinator.submit(frame, lease: lease)
        }
        await client.waitForFirstWrite()
        _ = await coordinator.stopCurrent(reason: .cancelled)
        await client.resumeFirstWrite()
        do {
            try await submission.value
            XCTFail("Cancelled write must become stale")
        } catch PlaybackCoordinationError.staleLease(let stale) {
            XCTAssertEqual(stale, lease)
        }
        let writes = await client.writeIDs()
        XCTAssertEqual(writes, [id("a")])
    }

    func testStoppingDuringSceneUpdatePreventsRecall() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let persistence = AppPersistence(suiteName: context.suite, writerVersion: "6.0.0-test")
        let area = makeArea()
        let sceneID = id("existing-scene")
        try await persistence.saveSceneID(sceneID, bridgeID: bridgeID, areaID: area.id)
        let matchingScene = try JSONDecoder().decode(
            HueSceneResource.self,
            from: Data(
                #"{"id":"existing-scene","group":{"rid":"room-one","rtype":"room"},"metadata":null}"#.utf8
            )
        )
        let client = FakePlaybackClient(
            areas: [area],
            existingScene: matchingScene,
            persistence: persistence,
            expectedJournalScope: .init(bridgeID: bridgeID, areaID: area.id),
            suspendUpdate: true
        )
        let transport = try makeBridgeTransport(client: client, persistence: persistence)
        let coordinator = PlaybackCoordinator()
        let request = try bridgeRequest(area: area)
        let begin = Task { [coordinator, request, transport] in
            try await coordinator.begin(request, using: transport)
        }
        await client.waitForSceneUpdate()
        let stopped = await coordinator.stopCurrent(reason: .cancelled)
        await client.resumeSceneUpdate()
        do {
            _ = try await begin.value
            XCTFail("Cancelled scene update must not proceed to recall")
        } catch PlaybackCoordinationError.staleLease(let stale) {
            XCTAssertEqual(stale, stopped)
        }
        let events = await client.events()
        XCTAssertEqual(events, ["inventory", "lookup", "update"])
    }

    private func makeBridgeTransport(
        client: FakePlaybackClient,
        persistence: AppPersistence
    ) throws -> BridgeSceneTransport {
        let contract = try HueBoardContractLoader.load()
        let preset = try XCTUnwrap(contract.presets.first)
        return BridgeSceneTransport(
            client: client,
            persistence: persistence,
            profile: try makeProfile(),
            credential: .init(bridgeID: bridgeID, applicationKey: "test-key"),
            contract: contract,
            preset: preset,
            brightness: 35
        )
    }

    private func bridgeRequest(area: HueArea) throws -> LightingPlaybackRequest {
        let preset = try XCTUnwrap(HueBoardContractLoader.load().presets.first)
        return .init(
            scope: .init(bridgeID: bridgeID, areaID: area.id),
            transport: .bridgeScene,
            presetID: preset.id
        )
    }

    private func makeProfile() throws -> BridgeProfile {
        try BridgeProfile(
            bridgeID: bridgeID,
            host: "192.168.1.2",
            certificateSHA256: fingerprint
        )
    }

    private func makeArea() -> HueArea {
        HueArea(
            id: id("room-one"),
            kind: .room,
            name: "Test room",
            lights: [
                makeLight("light-a", brightness: 22),
                makeLight("light-b", brightness: 44),
            ]
        )
    }

    private func makeLight(_ value: String, brightness: Double) -> HueLight {
        .init(
            id: id(value),
            ownerID: id("device-\(value)"),
            name: value,
            isOn: true,
            brightness: brightness,
            color: .init(x: 0.3, y: 0.3),
            colorTemperatureMirek: nil,
            gamut: nil,
            capabilities: .init(
                power: true,
                dimming: true,
                color: true,
                colorTemperature: false,
                dynamicPalette: true
            )
        )
    }

    private func id(_ value: String) -> HueResourceID {
        .init(rawValue: value)
    }

    private func makeContext() -> TestContext {
        let suite = "HueBoard.PlaybackTransportTests.\(UUID())"
        return .init(suite: suite, defaults: UserDefaults(suiteName: suite)!)
    }
}

private actor FakePlaybackClient: HueBridgePlaybackClient {
    private let areaValues: [HueArea]
    private let existingSceneValue: HueSceneResource?
    private let persistence: AppPersistence?
    private let expectedJournalScope: LightingScope?
    private let failRecall: Bool
    private let suspendUpdate: Bool
    private var sceneUpdateStarted = false
    private var sceneUpdateWaiter: CheckedContinuation<Void, Never>?
    private var sceneUpdateContinuation: CheckedContinuation<Void, Never>?
    private var recordedEvents: [String] = []
    private var recordedLightWrites: [HueResourceID] = []

    init(
        areas: [HueArea],
        existingScene: HueSceneResource? = nil,
        persistence: AppPersistence? = nil,
        expectedJournalScope: LightingScope? = nil,
        failRecall: Bool = false,
        suspendUpdate: Bool = false
    ) {
        areaValues = areas
        existingSceneValue = existingScene
        self.persistence = persistence
        self.expectedJournalScope = expectedJournalScope
        self.failRecall = failRecall
        self.suspendUpdate = suspendUpdate
    }

    func inventory(
        profile: BridgeProfile,
        credential: HueBridgeCredential,
        outputLimits: [HueResourceID: Double]
    ) async throws -> [HueArea] {
        recordedEvents.append("inventory")
        return areaValues
    }

    func sceneIfPresent(
        id: HueResourceID,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws -> HueSceneResource? {
        recordedEvents.append("lookup")
        return existingSceneValue
    }

    func createScene(
        _ scene: HueSceneCreateRequest,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws -> HueResourceID {
        try await assertJournalExists()
        recordedEvents.append("create")
        return .init(rawValue: "created-scene")
    }

    func updateScene(
        id: HueResourceID,
        scene: HueSceneUpdateRequest,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws {
        try await assertJournalExists()
        recordedEvents.append("update")
        if suspendUpdate {
            sceneUpdateStarted = true
            sceneUpdateWaiter?.resume()
            sceneUpdateWaiter = nil
            await withCheckedContinuation { continuation in
                sceneUpdateContinuation = continuation
            }
        }
    }

    func recallScene(
        id: HueResourceID,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws {
        try await assertJournalExists()
        recordedEvents.append("recall")
        if failRecall {
            throw HueBoardError.network("response lost after possible recall")
        }
    }

    func updateLight(
        id: HueResourceID,
        action: HueLightAction,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws {
        recordedLightWrites.append(id)
    }

    func events() -> [String] { recordedEvents }
    func lightWriteIDs() -> [HueResourceID] { recordedLightWrites }

    func waitForSceneUpdate() async {
        if sceneUpdateStarted { return }
        await withCheckedContinuation { continuation in
            sceneUpdateWaiter = continuation
        }
    }

    func resumeSceneUpdate() {
        sceneUpdateContinuation?.resume()
        sceneUpdateContinuation = nil
    }

    private func assertJournalExists() async throws {
        guard let persistence, let expectedJournalScope else { return }
        guard let journal = try await persistence.loadRestoreJournal(),
              journal.bridgeID == expectedJournalScope.bridgeID,
              journal.areaID == expectedJournalScope.areaID
        else {
            throw HueBoardError.invalidResponse("Physical mutation occurred before baseline capture.")
        }
    }
}

private actor SuspendingLightClient: HueLightUpdateSending {
    private var writes: [HueResourceID] = []
    private var firstWriteStarted = false
    private var firstWriteWaiter: CheckedContinuation<Void, Never>?
    private var firstWriteContinuation: CheckedContinuation<Void, Never>?

    func updateLight(
        id: HueResourceID,
        action: HueLightAction,
        profile: BridgeProfile,
        credential: HueBridgeCredential
    ) async throws {
        writes.append(id)
        if writes.count == 1 {
            firstWriteStarted = true
            firstWriteWaiter?.resume()
            firstWriteWaiter = nil
            await withCheckedContinuation { continuation in
                firstWriteContinuation = continuation
            }
        }
    }

    func waitForFirstWrite() async {
        if firstWriteStarted { return }
        await withCheckedContinuation { continuation in
            firstWriteWaiter = continuation
        }
    }

    func resumeFirstWrite() {
        firstWriteContinuation?.resume()
        firstWriteContinuation = nil
    }

    func writeIDs() -> [HueResourceID] { writes }
}

private struct TestContext {
    let suite: String
    let defaults: UserDefaults

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
    }
}
