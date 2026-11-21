import Foundation
import XCTest
@testable import HueBoardNativeCore

final class SetupImportIdleTests: XCTestCase {
    func testEmptyActiveMalformedAndLegacyRecordsAreInspectedWithoutMutation() async throws {
        let name = "HueBoard.SetupImportIdleTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = AppPersistence(suiteName: name)
        let initiallyIdle = try await store.isIdleForLocalImport()
        XCTAssertTrue(initiallyIdle)
        XCTAssertNil(defaults.object(forKey: "hue-board.native.state.v2"))
        XCTAssertNil(defaults.object(forKey: "hue-board.native.migration-report.v2"))

        defaults.set(Data("old journal".utf8), forKey: "hue-board.native.restore-journal.v1")
        let legacyPending = try await store.isIdleForLocalImport()
        XCTAssertFalse(legacyPending)
        defaults.removeObject(forKey: "hue-board.native.restore-journal.v1")
        try await store.saveLiveStatus(.init(sessionID: UUID(), state: .running, progress: 0.5,
                                            message: "Synthetic session", updatedAt: Date()))
        let active = try await store.isIdleForLocalImport()
        XCTAssertFalse(active)
        try await store.clearLiveSession()
        let afterStop = try await store.isIdleForLocalImport()
        XCTAssertTrue(afterStop)

        let malformed = Data("invalid".utf8)
        defaults.set(malformed, forKey: "hue-board.native.state.v2")
        do {
            _ = try await store.isIdleForLocalImport()
            XCTFail("An invalid state was accepted")
        } catch {
            XCTAssertEqual(defaults.data(forKey: "hue-board.native.state.v2"), malformed)
            XCTAssertNil(defaults.object(forKey: "hue-board.native.quarantine.v2"))
        }
    }
}
