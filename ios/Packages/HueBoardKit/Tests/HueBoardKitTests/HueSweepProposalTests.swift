import XCTest
@testable import HueBoardKit

final class HueSweepProposalTests: XCTestCase {
    func testRankedSweepKeepsTiesStaticExclusionsAndSafetySettings() throws {
        let fixture = try SyntheticHousehold.load()
        let expected = fixture.sweep
        let room = try fixture.room(expected.roomID)
        let area = room.area
        var before = room.layout
        let proposal = HueSweepProposal(layout: before, in: area, brightnessLimit: expected.brightnessLimit)
        XCTAssertEqual(proposal.distinctPositionCount, expected.distinctRanks)
        XCTAssertEqual(Set(proposal.eligibleIDs.map(\.rawValue)), Set(expected.eligibleIDs))
        var oracle = before
        XCTAssertEqual(Set(oracle.placements.map { $0.id.rawValue }), Set(expected.expectedPhases.keys))
        for index in oracle.placements.indices {
            let key = oracle.placements[index].id.rawValue
            oracle.placements[index].phase = try XCTUnwrap(expected.expectedPhases[key])
        }
        XCTAssertEqual(proposal.layout, oracle)
        XCTAssertEqual(Set(proposal.changes.map { $0.id.rawValue }), Set(expected.eligibleIDs))
        before.placements.reverse()
        let reversed = HueSweepProposal(layout: before, in: area, brightnessLimit: expected.brightnessLimit)
        XCTAssertEqual(reversed.layout.placements, Array(oracle.placements.reversed()))
        XCTAssertTrue(HueSweepProposal(layout: oracle, in: area, brightnessLimit: expected.brightnessLimit).changes.isEmpty)
    }

    func testOneDistinctPositionPreservesManualPhases() throws {
        let fixture = try SyntheticHousehold.load()
        let room = try fixture.room(fixture.sweep.roomID)
        let area = room.area
        var layout = room.layout
        for index in layout.placements.indices { layout.placements[index].x = 0.2 }
        let sweep = HueSweepProposal(layout: layout, in: area, brightnessLimit: 100)
        XCTAssertTrue(sweep.changes.isEmpty)
        XCTAssertEqual(sweep.layout, layout)
    }
}
