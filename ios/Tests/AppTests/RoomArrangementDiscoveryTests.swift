import XCTest
import HueBoardKit
@testable import Hue_Board

@MainActor
final class RoomArrangementDiscoveryTests: XCTestCase {
    func testLateReadFromPreviousVisitCannotReplaceNewerResult() async throws {
        let session = RoomDiscoverySession()
        let scope = RoomDiscoveryScope(bridgeID: "a", areaID: .init(rawValue: "room"), fixtureIDs: [], revision: 1)
        let (events, started) = AsyncStream<Void>.makeStream()
        var reader = events.makeAsyncIterator()
        var resume: CheckedContinuation<HueRoomDiscovery, Never>?
        let oldRead = Task {
            await session.read(scope: scope, revision: 0) { _ in
                await withCheckedContinuation { continuation in
                    resume = continuation
                    started.yield(())
                    started.finish()
                }
            }
        }
        _ = await reader.next()
        await session.read(scope: scope, revision: 0) { _ in XCTFail("Duplicated read"); return .noSavedAreas }
        await session.read(scope: nil, revision: 0) { _ in XCTFail("Read while unavailable"); return .noSavedAreas }
        await session.read(scope: scope, revision: 0) { _ in .noMatchingPositions }
        try XCTUnwrap(resume).resume(returning: .noSavedAreas)
        await oldRead.value
        XCTAssertEqual(session.state, .loaded(.noMatchingPositions))
    }

    func testRetryAfterFailureAndNewMembership() async {
        let session = RoomDiscoverySession()
        let first = RoomDiscoveryScope(bridgeID: "a", areaID: .init(rawValue: "r"), fixtureIDs: [], revision: 1)
        await session.read(scope: first, revision: 0) { _ in throw HueBoardError.network("fixture unavailable") }
        guard case .failed = session.state else { return XCTFail("Expected read failure") }
        await session.read(scope: first, revision: 1) { _ in .noSavedAreas }
        let next = RoomDiscoveryScope(bridgeID: "a", areaID: first.areaID, fixtureIDs: [.init(rawValue: "l")], revision: 2)
        await session.read(scope: next, revision: 1) { _ in .noMatchingPositions }
        XCTAssertEqual(session.scope, next)
        XCTAssertEqual(session.state, .loaded(.noMatchingPositions))
    }
}
