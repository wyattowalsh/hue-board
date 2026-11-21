import SwiftUI
import HueBoardKit

struct RoomArrangementSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var session = RoomDiscoverySession()
    @State private var refresh = 0
    @State private var preview: RoomArrangementPreview?
    let onManual: () -> Void

    private struct Request: Hashable {
        let scope: RoomDiscoveryScope?
        let refresh: Int
    }

    var body: some View {
        let scope = model.selectedTab == .room && scenePhase == .active ? model.roomDiscoveryScope : nil
        RoomDiscoveryCard(
            state: scope != nil && scope == session.scope ? session.state : .idle,
            canRead: scope != nil,
            onRefresh: { refresh &+= 1 },
            onManual: onManual
        ) { arrangement in
            guard let scope, scope == session.scope else { return }
            do { preview = try model.previewRoomArrangement(arrangement, from: scope) }
            catch { model.errorMessage = error.localizedDescription }
        }
        .task(id: Request(scope: scope, refresh: refresh)) {
            await session.read(scope: scope, revision: refresh, using: model.fetchRoomArrangements)
        }
        .onDisappear { session.invalidate() }
        .sheet(item: $preview) { RoomArrangementPreviewSheet(preview: $0) }
    }
}

struct RoomDiscoveryCard: View {
    let state: RoomDiscoverySession.State
    let canRead: Bool
    let onRefresh: () -> Void
    let onManual: () -> Void
    let onPreview: (HueRoomArrangement) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Saved Hue layouts", systemImage: "square.stack")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            switch state {
            case .idle:
                Text(canRead ? "Checking for saved layouts…" : "Saved layouts are available when the Bridge is connected and idle.")
                    .font(.subheadline)
            case .loading:
                ProgressView("Reading saved layouts")
            case .failed(let reason):
                Text("Couldn’t read saved Hue layouts. \(reason)")
                    .accessibilityIdentifier("room-layout-error")
            case .loaded(.noSavedAreas):
                Text("Your Bridge has no saved Entertainment areas. Apple Home rooms provide membership only. Arrange lights on the map, or save positions in the Hue app.")
                    .accessibilityIdentifier("room-layout-none")
                manualButton
            case .loaded(.noMatchingPositions):
                Text("Your Bridge has saved Entertainment areas, but none have usable positions for lights in this room.")
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
            Button(state.isFailure ? "Retry layout discovery" : "Refresh layouts", systemImage: "arrow.clockwise", action: onRefresh)
                .disabled(!canRead || state == .loading)
                .accessibilityIdentifier("room-layout-refresh")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
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
