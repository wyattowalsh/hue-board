#if DEBUG && targetEnvironment(simulator)
import SwiftUI
import HueBoardKit

/// An isolated rendering host for the real discovery card, map and preview sheet.
struct RoomDiscoveryFixture: View {
    enum Scenario: String { case partial, empty, unmatched, unavailable }
    let scenario: Scenario
    @State private var preview: RoomArrangementPreview?
    @State private var retried = false
    private let room = StudioRehearsalRoom.sample

    static var requestedScenario: Scenario? {
        let env = ProcessInfo.processInfo.environment
        guard env["HUE_BOARD_UI_TEST_MODE"] == "1" else { return nil }
        return Scenario(rawValue: env["HUE_BOARD_ROOM_FIXTURE"] ?? "")
    }

    private var state: RoomDiscoverySession.State {
        switch scenario {
        case .empty: return .loaded(.noSavedAreas)
        case .unmatched: return .loaded(.noMatchingPositions)
        case .unavailable: return retried ? .loaded(.noSavedAreas) : .failed("Fixture connection unavailable.")
        case .partial:
            let json = #"""
            [{"id":"sample-layout","name":"Upstairs movie and game lighting for the long west living room",
              "locations":{"service_locations":[{"service":{"rid":"sample-1","rtype":"light"},"position":{"x":0.5,"y":-0.75,"z":0}}]}}]
            """#
            do {
                let resources = try JSONDecoder().decode([HueEntertainmentConfigurationResource].self, from: Data(json.utf8))
                return .loaded(HueRoomDiscovery(configurations: resources, services: [], in: room.area))
            } catch { return .failed(error.localizedDescription) }
        }
    }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 16) {
                    RoomDiscoveryCard(state: state, canRead: true, onRefresh: { retried = true },
                                      onManual: { reader.scrollTo("fixture-map", anchor: .top) }) { option in
                        guard let proposed = try? option.applying(to: room.layout, in: room.area) else { return }
                        preview = .init(scope: .init(bridgeID: "sample", areaID: room.area.id,
                                                     fixtureIDs: Set(room.area.lights.map(\.id)), revision: 0),
                                        area: room.area, arrangement: option, originalLayout: room.layout, proposedLayout: proposed)
                    }
                    RoomFixtureMap(area: room.area, layout: room.layout, focusedID: nil, isEditable: false,
                                   onFocus: { _ in }, onMove: { _, _, _ in })
                        .id("fixture-map")
                }
                .padding()
            }
        }
        .navigationTitle("Room")
        .sheet(item: $preview) { RoomArrangementPreviewSheet(preview: $0) }
    }
}
#endif
