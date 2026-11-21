import SwiftUI
import HueBoardKit

struct RoomLayoutView: View {
    @Environment(AppModel.self) private var model
    @State private var showResetConfirmation = false
    @State private var sweepPreview: RoomSweepPreview?
    @State private var showingPosition = false
    @State private var showingStudioControls = false
    @State private var session = RoomDiscoverySession()
    @State private var refresh = 0
    @State private var layoutPreview: RoomArrangementPreview?
    @Environment(\.scenePhase) private var scenePhase

    private struct LayoutRequest: Hashable {
        let scope: RoomDiscoveryScope?
        let revision: Int
    }

    private var discoveryScope: RoomDiscoveryScope? {
        model.selectedTab == .room && scenePhase == .active ? model.roomDiscoveryScope : nil
    }

    private var visibleDiscovery: RoomDiscoverySession.State {
        guard let scope = discoveryScope, scope == session.scope else { return .idle }
        return session.state
    }

    private var hasMatchingLayouts: Bool {
        if case .loaded(.matches) = visibleDiscovery { return true }
        return false
    }

    private var activePlacement: HueFixturePlacement? {
        model.roomLayout?.placements.first(where: { $0.id == model.focusedFixtureID })
    }

    @ViewBuilder
    var body: some View {
        #if DEBUG && targetEnvironment(simulator)
        if let scenario = RoomDiscoveryFixture.requestedScenario {
            RoomDiscoveryFixture(scenario: scenario)
        } else {
            roomContent
        }
        #else
        roomContent
        #endif
    }

    private var roomContent: some View {
        Group {
            if model.isReady {
                ScrollViewReader { reader in
                    Form {
                        Section { AreaPicker() }
                        if let issue = model.roomLayoutIssue {
                            Label(issue, systemImage: "exclamationmark.triangle")
                        } else if let area = model.selectedArea, let layout = model.roomLayout {
                            let scope = discoveryScope
                            let hueLayouts = RoomDiscoveryCard(
                                state: visibleDiscovery, canRead: scope != nil,
                                onRefresh: { refresh &+= 1 },
                                onManual: { reader.scrollTo("room-map", anchor: .top) }
                            ) { arrangement in
                                guard let scope, scope == discoveryScope, scope == session.scope else { return }
                                do { layoutPreview = try model.previewRoomArrangement(arrangement, from: scope) }
                                catch { model.errorMessage = error.localizedDescription }
                            }
                            Section {
                                RoomFixtureMap(
                                    area: area, layout: layout, focusedID: model.focusedFixtureID,
                                    isEditable: model.canEditRoomLayout,
                                    onFocus: { model.focusedFixtureID = $0 },
                                    onMove: { id, x, y in
                                        model.updateRoomFixture(id) {
                                            $0.x = x
                                            $0.y = y
                                        }
                                    }
                                )
                                .id("room-map")
                                if hasMatchingLayouts { hueLayouts }
                                Picker("Light", selection: Binding(
                                    get: { model.focusedFixtureID },
                                    set: { model.focusedFixtureID = $0 }
                                )) {
                                    ForEach(Array(layout.placements.enumerated()), id: \.element.id) { index, placement in
                                        if let light = area.lights.first(where: { $0.id == placement.id }) {
                                            Text("\(index + 1) · \(light.name)").tag(Optional(light.id))
                                        }
                                    }
                                }
                                .accessibilityIdentifier("room-focused-light")

                                if let placement = activePlacement,
                                   let light = area.lights.first(where: { $0.id == placement.id }) {
                                    DisclosureGroup("Fine-tune position", isExpanded: $showingPosition) {
                                        placementSlider("Position X", id: light.id, keyPath: \.x,
                                                        range: 0...1, percentage: true)
                                        placementSlider("Position Y", id: light.id, keyPath: \.y,
                                                        range: 0...1, percentage: true)
                                    }
                                    .accessibilityIdentifier("room-position-controls")
                                    studioControls(for: light, placement: placement)
                                }
                            } header: {
                                Text("Light positions")
                                    .accessibilityIdentifier("room-arrangement-heading")
                            } footer: {
                                if model.canEditRoomLayout {
                                    Text("Drag a light to save its position in Hue Board.")
                                } else {
                                    Text("Position editing is available when the room is idle and any previous settings have been restored.")
                                }
                            }

                            if !hasMatchingLayouts {
                                Section { hueLayouts }
                            }
                            Section("Layout tools") {
                                Button("Preview left-to-right sweep", systemImage: "arrow.right") {
                                    do { sweepPreview = try model.previewRoomSweep() }
                                    catch { model.errorMessage = error.localizedDescription }
                                }
                                .disabled(model.roomDiscoveryScope == nil)
                                .accessibilityIdentifier("room-sweep-preview")
                                Button("Reset room layout", role: .destructive) {
                                    showResetConfirmation = true
                                }
                                .disabled(!model.canEditRoomLayout)
                                .confirmationDialog("Reset this layout?", isPresented: $showResetConfirmation,
                                                    titleVisibility: .visible) {
                                    Button("Reset layout", role: .destructive) { model.resetRoomLayoutToRing() }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("Places lights in a ring and restores their default Studio settings in Hue Board.")
                                }
                            }
                        } else {
                            ContentUnavailableView("No room layout", systemImage: "square.grid.3x3",
                                                   description: Text("Choose a Hue room or zone with lights."))
                        }
                    }
                }
            } else {
                ConnectPrompt()
            }
        }
        .task(id: LayoutRequest(scope: discoveryScope, revision: refresh)) {
            await session.read(scope: discoveryScope, revision: refresh, using: model.fetchRoomArrangements)
        }
        .onDisappear { session.invalidate() }
        .sheet(item: $layoutPreview) { RoomArrangementPreviewSheet(preview: $0) }
        .sheet(item: $sweepPreview) { RoomSweepSheet(preview: $0) }
        .navigationTitle("Room")
    }

    private func studioControls(for light: HueLight, placement: HueFixturePlacement) -> some View {
        DisclosureGroup("Studio settings for this light", isExpanded: $showingStudioControls) {
            Toggle("Include in Studio", isOn: Binding(
                get: { placement.selected },
                set: { enabled in model.updateRoomFixture(light.id) { $0.selected = enabled } }
            ))
            .disabled(!model.canEditRoomLayout)
            Picker("Role", selection: Binding(
                get: { placement.role },
                set: { role in model.updateRoomFixture(light.id) { $0.role = role } }
            )) {
                ForEach(HueFixtureRole.allCases, id: \.self) { role in
                    Text(role.title).tag(role)
                }
            }
            .disabled(!model.canEditRoomLayout)
            placementSlider("Animation phase", id: light.id, keyPath: \.phase, range: 0...1, percentage: true)
            placementSlider("Brightness scale", id: light.id, keyPath: \.trim, range: 0.1...1, percentage: true, identifier: "room-output-trim")
            placementSlider("Brightness limit", id: light.id, keyPath: \.ceiling, range: 5...100, percentage: false, identifier: "room-output-ceiling")
            if light.outputLimit < 100 {
                LabeledContent("Light’s maximum", value: "\(Int(light.outputLimit))%")
            }
        }
        .accessibilityIdentifier("room-studio-controls")
    }

    private func placementSlider(
        _ title: String,
        id: HueResourceID,
        keyPath: WritableKeyPath<HueFixturePlacement, Double>,
        range: ClosedRange<Double>,
        percentage: Bool, identifier: String? = nil
    ) -> some View {
        let current = model.roomLayout?.placements.first(where: { $0.id == id })?[keyPath: keyPath]
            ?? range.lowerBound
        let displayValue = "\(Int((current * (percentage ? 100 : 1)).rounded()))%"
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(displayValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
            Slider(value: Binding(
                get: {
                    model.roomLayout?.placements.first(where: { $0.id == id })?[keyPath: keyPath]
                        ?? range.lowerBound
                },
                set: { next in
                    model.updateRoomFixture(id) { placement in
                        placement[keyPath: keyPath] = next
                    }
                }
            ), in: range, step: percentage ? 0.01 : 5)
                .disabled(!model.canEditRoomLayout)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier ?? title)
                .accessibilityValue(displayValue)
        }
    }
}

struct RoomArrangementPreviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var focusedID: HueResourceID?
    @State private var failure: String?

    let preview: RoomArrangementPreview

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(preview.arrangement.name)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(preview.area.name)
                        .foregroundStyle(.secondary)
                    RoomFixtureMap(
                        area: preview.area,
                        layout: preview.proposedLayout,
                        focusedID: focusedID,
                        isEditable: false,
                        onFocus: { focusedID = $0 },
                        onMove: { _, _, _ in }
                    )
                    DisclosureGroup("Compare positions") {
                        ForEach(preview.area.lights.filter { preview.arrangement.hasPosition(for: $0.id) }) { light in
                            if let previous = preview.originalLayout.placements.first(where: { $0.id == light.id }),
                               let proposed = preview.proposedLayout.placements.first(where: { $0.id == light.id }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(light.name).font(.headline)
                                    Text("Current · \(mapCoordinates(previous))")
                                    Text("From Hue · \(mapCoordinates(proposed))")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                    .accessibilityIdentifier("room-layout-comparison")
                    Text("Save the matching positions to Hue Board for this room. Other light settings stay as they are.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !model.canSaveRoomArrangement(preview) {
                        Text("The room or playback state changed. Cancel and preview the layout again.")
                            .font(.footnote)
                    }
                    if let failure {
                        Label(failure, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                    }
                }
                .padding()
            }
            .navigationTitle("Preview Hue layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("room-layout-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save positions") {
                        do {
                            try model.saveRoomArrangement(preview)
                            dismiss()
                        } catch {
                            failure = error.localizedDescription
                        }
                    }
                    .disabled(!model.canSaveRoomArrangement(preview))
                    .accessibilityIdentifier("room-layout-save")
                }
            }
        }
    }
}

private func mapCoordinates(_ placement: HueFixturePlacement) -> String {
    let across = placement.x.formatted(.percent.precision(.fractionLength(0)))
    let down = placement.y.formatted(.percent.precision(.fractionLength(0)))
    return "\(across) from the left, \(down) from the front"
}

struct RoomFixtureMap: View {
    let area: HueArea
    let layout: HueRoomLayout
    let focusedID: HueResourceID?
    let isEditable: Bool
    let onFocus: (HueResourceID) -> Void
    let onMove: (HueResourceID, Double, Double) -> Void

    @State private var previewPositions: [HueResourceID: CGPoint] = [:]

    private let markerSize: CGFloat = 44

    var body: some View {
        VStack(spacing: 4) {
            Text("Front").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
            map
            Text("Back").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
        }
    }

    private var map: some View {
        GeometryReader { geometry in
            let inset = markerSize / 2
            let mapSize = CGSize(
                width: max(1, geometry.size.width - markerSize),
                height: max(1, geometry.size.height - markerSize)
            )
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.12))
                Path { path in
                    for fraction in [CGFloat(0.25), 0.5, 0.75] {
                        let x = inset + mapSize.width * fraction
                        let y = inset + mapSize.height * fraction
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.secondary.opacity(0.28), lineWidth: 1)

                ForEach(Array(layout.placements.enumerated()), id: \.element.id) { index, placement in
                    if let light = area.lights.first(where: { $0.id == placement.id }) {
                        let point = previewPositions[placement.id] ?? CGPoint(
                            x: placement.x, y: placement.y
                        )
                        Button {
                            onFocus(placement.id)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(swiftUIColor(light.color).opacity(placement.selected ? 1 : 0.35))
                                Circle()
                                    .strokeBorder(
                                        focusedID == placement.id ? Color.accentColor : Color.secondary.opacity(0.5),
                                        lineWidth: focusedID == placement.id ? 3 : 1
                                    )
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(.black.opacity(0.8), in: Capsule())
                            }
                            .frame(width: markerSize, height: markerSize)
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(light.name)
                        .accessibilityValue("\(mapCoordinates(placement)). \(placement.selected ? "Selected for Studio" : "Excluded from Studio")")
                        .accessibilityAddTraits(focusedID == placement.id ? [.isSelected] : [])
                        .accessibilityHint(isEditable ? "Selects this light for editing" : "Selects this light on the map")
                        .position(
                            x: inset + point.x * mapSize.width,
                            y: inset + point.y * mapSize.height
                        )
                        .zIndex(focusedID == placement.id ? 1 : 0)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .named("room-map"))
                                .onChanged { drag in
                                    guard isEditable else { return }
                                    previewPositions[placement.id] = position(
                                        after: drag.translation, from: placement, in: mapSize
                                    )
                                }
                                .onEnded { drag in
                                    defer { previewPositions.removeValue(forKey: placement.id) }
                                    guard isEditable else { return }
                                    let next = position(after: drag.translation, from: placement, in: mapSize)
                                    onMove(placement.id, Double(next.x), Double(next.y))
                                    onFocus(placement.id)
                                }
                        )
                    }
                }
            }
            .coordinateSpace(name: "room-map")
        }
        .frame(height: layout.placements.count > 6 ? 260 : 200)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Room map, front at the top")
    }

    private func position(
        after translation: CGSize,
        from placement: HueFixturePlacement,
        in mapSize: CGSize
    ) -> CGPoint {
        CGPoint(
            x: min(max(CGFloat(placement.x) + translation.width / mapSize.width, 0), 1),
            y: min(max(CGFloat(placement.y) + translation.height / mapSize.height, 0), 1)
        )
    }
}
