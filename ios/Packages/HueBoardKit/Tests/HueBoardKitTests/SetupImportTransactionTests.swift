import Foundation
import XCTest
@testable import HueBoardKit

final class SetupImportTransactionTests: XCTestCase {
    private typealias Import = SetupImportTransaction
    private static let laboratory = Import.Section.layout(bridgeID: "fake-bridge", areaID: "fake-area")

    func testRestartAtEveryBoundaryPreservesCompleteOldOrNewSettings() throws {
        let checkpoints: [Import.Checkpoint] = [
            .beforePrepare, .prepared, .applied(0), .applied(1), .applied(2), .applied(3), .committed
        ]
        for checkpoint in checkpoints {
            let suite = "HueBoard.SetupTransactionTests.\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let oldLibrary = Data("previous library".utf8)
            let oldSafety = Data("device consent and safety settings".utf8)
            let outside = ["hue-board.native.state.v2", "hue-board.native.recovery.v2",
                           "hue-board.native.legacy-backup.v1"]
            for key in outside { defaults.set(Data(key.utf8), forKey: key) }
            defaults.set(oldLibrary, forKey: Import.Section.library.preferenceKey)
            defaults.set(oldSafety, forKey: Import.Section.safety.preferenceKey)
            try Import.saveFavorites(["first"], defaults: defaults)
            let replacement: [Import.Section: Import.Value] = [
                .favorites: .identifiers(["next"]), .library: .data(Data("next library".utf8)),
                .safety: .data(Data("new safety with local consent".utf8)),
                Self.laboratory: .data(Data("new positions".utf8))
            ]
            let old = try Import.fingerprint(for: Set(replacement.keys), defaults: defaults)
            XCTAssertThrowsError(try Import.commit(replacement, expected: old, defaults: defaults) { boundary in
                if boundary == checkpoint { throw Termination.simulated }
            })
            // Materialize the worst case where partial writes reached preferences before process death.
            XCTAssertTrue(defaults.synchronize())
            let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
            let committed = checkpoint == .committed
            XCTAssertEqual(try Import.loadFavorites(defaults: reopened), committed ? ["next"] : ["first"])
            XCTAssertEqual(reopened.data(forKey: Import.Section.library.preferenceKey),
                           committed ? Data("next library".utf8) : oldLibrary)
            XCTAssertEqual(reopened.data(forKey: Import.Section.safety.preferenceKey),
                           committed ? Data("new safety with local consent".utf8) : oldSafety)
            XCTAssertEqual(reopened.data(forKey: Self.laboratory.preferenceKey),
                           committed ? Data("new positions".utf8) : nil)
            try Import.recover(defaults: reopened)
            try Import.saveFavorites(["later edit"], defaults: reopened)
            try Import.recover(defaults: reopened)
            XCTAssertEqual(try Import.loadFavorites(defaults: reopened), ["later edit"])
            for key in outside { XCTAssertEqual(reopened.data(forKey: key), Data(key.utf8)) }
        }
    }

    func testNormalSameCountEditRejectsStaleReviewAndPreventsOtherSectionUpdates() throws {
        let suite = "HueBoard.SetupTransactionTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try Import.saveFavorites(["look-a"], defaults: defaults)
        let expected = try Import.fingerprint(for: [.favorites, .library], defaults: defaults)
        try Import.saveFavorites(["look-b"], defaults: defaults)
        XCTAssertThrowsError(try Import.commit([
            .favorites: .identifiers(["look-c"]), .library: .data(Data("import".utf8))
        ], expected: expected, defaults: defaults))
        XCTAssertEqual(try Import.loadFavorites(defaults: defaults), ["look-b"])
        XCTAssertNil(defaults.object(forKey: Import.Section.library.preferenceKey))
    }

    func testCorruptTransactionPreservesItselfAndFailsBeforeWritingAnySection() throws {
        let suite = "HueBoard.SetupTransactionTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let marker = "hue-board.native.setup-import-transaction.v1"
        let expected = try Import.fingerprint(for: [.favorites], defaults: defaults)
        XCTAssertThrowsError(try Import.commit([.favorites: .identifiers(["new"])], expected: expected,
                                              defaults: defaults) { checkpoint in
            if checkpoint == .prepared { throw Termination.simulated }
        })
        let original = try XCTUnwrap(defaults.data(forKey: marker))
        var envelope = try XCTUnwrap(PropertyListSerialization.propertyList(from: original, format: nil) as? [String: Any])
        envelope["sha256"] = "damaged"
        let damaged = try PropertyListSerialization.data(fromPropertyList: envelope, format: .binary, options: 0)
        defaults.set(damaged, forKey: marker)
        XCTAssertThrowsError(try Import.recover(defaults: defaults))
        XCTAssertThrowsError(try Import.saveFavorites(["another"], defaults: defaults))
        XCTAssertEqual(defaults.data(forKey: marker), damaged)
        XCTAssertNil(defaults.object(forKey: Import.Section.favorites.preferenceKey))
    }

    func testOrdinaryReaderDuringImportGetsTheCompleteCommittedSet() throws {
        let suite = "HueBoard.SetupTransactionTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let newLibrary = Data("reviewed library".utf8)
        let changes: [Import.Section: Import.Value] = [
            .favorites: .identifiers(["reviewed look"]), .library: .data(newLibrary)
        ]
        let old = try Import.fingerprint(for: Set(changes.keys), defaults: defaults)
        let partialWrite = DispatchSemaphore(value: 0)
        let readerIsStarting = DispatchSemaphore(value: 0)
        let finishedReading = expectation(description: "ordinary setup reader finishes")
        DispatchQueue.global().async {
            defer { finishedReading.fulfill() }
            guard partialWrite.wait(timeout: .now() + 5) == .success,
                  let concurrentDefaults = UserDefaults(suiteName: suite) else {
                XCTFail("Reader did not reach the partial write")
                return
            }
            readerIsStarting.signal()
            do {
                // Enter an actual ordinary preference read while the import holds the lock.
                let favorites = try Import.loadFavorites(defaults: concurrentDefaults)
                XCTAssertEqual(favorites, ["reviewed look"])
                XCTAssertEqual(concurrentDefaults.data(forKey: Import.Section.library.preferenceKey), newLibrary)
            } catch {
                XCTFail("Unexpected concurrent read failure: \(error)")
            }
        }
        try Import.commit(changes, expected: old, defaults: defaults) { boundary in
            if boundary == .applied(0) {
                partialWrite.signal()
                XCTAssertEqual(readerIsStarting.wait(timeout: .now() + 5), .success)
            }
        }
        wait(for: [finishedReading], timeout: 10)

        // Marker cleanup must be durable before an ordinary post-import edit.
        try Import.saveFavorites(["subsequent edit"], defaults: defaults)
        XCTAssertTrue(defaults.synchronize())
        let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertEqual(try Import.loadFavorites(defaults: reopened), ["subsequent edit"])
        XCTAssertEqual(reopened.data(forKey: Import.Section.library.preferenceKey), newLibrary)
    }

    private enum Termination: Error { case simulated }
}
