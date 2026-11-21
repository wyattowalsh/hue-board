import XCTest
import HueBoardKit
@testable import HueBoardNativeCore

final class RoomDiscoveryClientTests: XCTestCase {
    private let room = HueArea(id: .init(rawValue: "area"), kind: .room, name: "Room", lights: [])

    func testEmptyRequiresTwoSuccessfulReads() async throws {
        let result = try await RoomDiscoveryReader.read(in: room, configurations: { [] }, services: { [] })
        XCTAssertEqual(result, .noSavedAreas)
        do {
            _ = try await RoomDiscoveryReader.read(in: room, configurations: { [] },
                                                   services: { throw HueBoardError.network("test unavailable") })
            XCTFail("A failed service read must be visible")
        } catch HueBoardError.network(let detail) {
            XCTAssertEqual(detail, "test unavailable")
        }
    }

    func testCancellationNeverProducesAnEmptyInventory() async throws {
        let room = self.room
        let task = Task {
            try await RoomDiscoveryReader.read(in: room, configurations: {
                try await Task.sleep(for: .seconds(60))
                return []
            }, services: { [] })
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A cancelled read must not return a layout outcome")
        } catch is CancellationError {}
    }
}
