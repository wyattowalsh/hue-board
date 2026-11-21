import SwiftUI
import HueBoardKit

struct RoomDiscoveryCard: View {
    let state: RoomDiscoverySession.State
    let canRead: Bool
    let onRefresh: () -> Void
    let onManual: () -> Void
    let onPreview: (HueRoomArrangement) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Layouts from Hue", systemImage: "square.stack")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if canRead {
                    Button(action: onRefresh) {
                        Label(state.isFailure ? "Retry layout discovery" : "Refresh layouts", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .disabled(state == .loading)
                    .accessibilityIdentifier("room-layout-refresh")
                }
            }
            switch state {
            case .idle:
                Text(canRead ? "Checking Hue layouts…" : "Saved positions will load when the room is ready to edit.")
                    .font(.subheadline)
            case .loading:
                ProgressView("Reading saved layouts")
            case .failed(let reason):
                Text("Couldn’t read saved Hue layouts. \(reason)")
                    .accessibilityIdentifier("room-layout-error")
            case .loaded(.noSavedAreas):
                Text("Create an Entertainment area in the Hue app to import light positions.")
                    .accessibilityIdentifier("room-layout-none")
                manualButton
            case .loaded(.noMatchingPositions):
                Text("No saved Entertainment area includes positions for these lights.")
                    .accessibilityIdentifier("room-layout-no-overlap")
                manualButton
            case let .loaded(.matches(options, fixtureCount)):
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    let coverage = "\(option.matchedCount) of \(fixtureCount) lights have positions"
                    let duplicateName = options.filter { $0.name == option.name }.count > 1
                    Button { onPreview(option) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.name).font(.subheadline.weight(.semibold))
                            Text(coverage).font(.callout)
                            if duplicateName { Text("Layout \(index + 1) of \(options.count)").font(.caption) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Preview these positions")
                    .accessibilityIdentifier("room-layout-candidate-\(index)")
                    .disabled(!canRead)
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.borderless)
    }

    private var manualButton: some View {
        Button("Arrange lights on the map", systemImage: "square.grid.3x3", action: onManual)
            .accessibilityIdentifier("room-layout-manual")
    }
}

private extension RoomDiscoverySession.State {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
