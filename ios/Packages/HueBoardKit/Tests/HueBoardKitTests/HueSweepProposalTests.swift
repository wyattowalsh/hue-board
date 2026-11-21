import XCTest
@testable import HueBoardKit

final class HueSweepProposalTests: XCTestCase {
    private func room() -> HueArea {
        let names = ["right", "left", "mid-a", "mid-b", "steady", "excluded", "bright-min"]
        return .init(id: .init(rawValue: "r"), kind: .room, name: "Room", lights: names.map { name in
            .init(id: .init(rawValue: name), ownerID: nil, name: name, isOn: true, brightness: 50,
                  color: nil, colorTemperatureMirek: nil, gamut: nil,
                  capabilities: .init(power: true, dimming: true, color: true, colorTemperature: false, dynamicPalette: true),
                  minimumBrightness: name == "bright-min" ? 70 : 1)
        })
    }

    func testRankedSweepKeepsTiesStaticExclusionsAndSafetySettings() {
        let area = room()
        var before = HueRoomLayout.startingLayout(for: area)
        let xs = [0.9, 0.1, 0.3, 0.3, 0.2, 0.4, 0.8]
        for index in before.placements.indices {
            before.placements[index].x = xs[index]
            before.placements[index].phase = 0.91
            before.placements[index].trim = 0.8
            before.placements[index].ceiling = 85
        }
        before.placements[4].role = .task
        before.placements[5].selected = false
        let proposal = HueSweepProposal(layout: before, in: area, brightnessLimit: 50)
        XCTAssertEqual(proposal.distinctPositionCount, 3)
        let expected = [2.0/3, 0, 1.0/3, 1.0/3, 0.91, 0.91, 0.91]
        var oracle = before
        for index in oracle.placements.indices { oracle.placements[index].phase = expected[index] }
        XCTAssertEqual(proposal.layout, oracle)
        XCTAssertEqual(proposal.changes.count, 4)
        before.placements.reverse()
        let reversed = HueSweepProposal(layout: before, in: area, brightnessLimit: 50)
        XCTAssertEqual(reversed.layout.placements, Array(oracle.placements.reversed()))
        XCTAssertTrue(HueSweepProposal(layout: oracle, in: area, brightnessLimit: 50).changes.isEmpty)
    }

    func testOneDistinctPositionPreservesManualPhases() {
        let area = room()
        var layout = HueRoomLayout.startingLayout(for: area)
        for index in layout.placements.indices { layout.placements[index].x = 0.2 }
        let sweep = HueSweepProposal(layout: layout, in: area, brightnessLimit: 100)
        XCTAssertTrue(sweep.changes.isEmpty)
        XCTAssertEqual(sweep.layout, layout)
    }
}
