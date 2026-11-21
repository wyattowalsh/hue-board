import SwiftUI
import HueBoardKit

struct RoomLayoutView: View {
    @Environment(AppModel.self) private var model
    @State private var showResetConfirmation = false
    @State private var sweepPreview: RoomSweepPreview?

    private var activePlacement: HueFixturePlacement? {
        model.roomLayout?.placements.first(where: { $0.id == model.focusedFixtureID })
    }

    var body: some View {
        Group {
            if !model.isReady {
                ConnectPrompt()
            } else {
                ScrollViewReader { reader in
                  ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        StatusCard()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Room arrangement")
                                .font(.title2.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text("Arrange lights by position and phase. Editing the map never changes your bulbs.")
                                .foregroundStyle(.secondary)
                        }
                        AreaPicker()
                        if model.roomLayout != nil {
                            RoomArrangementSection { reader.scrollTo("room-map", anchor: .top) }
                        }

                        if let issue = model.roomLayoutIssue {
                            Label(issue, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        } else if let area = model.selectedArea,
                                  let layout = model.roomLayout {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("Spatial map", systemImage: "circle.hexagongrid")
                                        .font(.headline)
                                        .accessibilityAddTraits(.isHeader)
                                    Spacer()
                                    Text("\(layout.selectedEntries(in: area).count) active")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                RoomFixtureMap(
                                    area: area,
                                    layout: layout,
                                    focusedID: model.focusedFixtureID,
                                    isEditable: model.canEditRoomLayout,
                                    onFocus: { model.focusedFixtureID = $0 },
                                    onMove: { id, x, y in
                                        model.updateRoomFixture(id) { placement in
                                            placement.x = x
                                            placement.y = y
                                        }
                                    }
                                )
                                Text(model.canEditRoomLayout
                                    ? "Tap a light to choose it. Drag it or use Position X and Y to move it."
                                    : "Choose a fixture to inspect its settings.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))

                            .id("room-map")

                            Button("Use positions for sweep", systemImage: "arrow.right") {
                                do { sweepPreview = try model.previewRoomSweep() }
                                catch { model.errorMessage = error.localizedDescription }
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.roomDiscoveryScope == nil)
                            .accessibilityIdentifier("room-sweep-preview")

                            VStack(alignment: .leading, spacing: 16) {
                                Picker("Fixture", selection: Binding(
                                    get: { model.focusedFixtureID },
                                    set: { model.focusedFixtureID = $0 }
                                )) {
                                    ForEach(area.lights) { light in
                                        Text(light.name).tag(Optional(light.id))
                                    }
                                }

                                if let placement = activePlacement,
                                   let light = area.lights.first(where: { $0.id == placement.id }) {
                                    Toggle("Include in Studio", isOn: Binding(
                                        get: { placement.selected },
                                        set: { enabled in
                                            model.updateRoomFixture(light.id) {
                                                $0.selected = enabled
                                            }
                                        }
                                    ))
                                    .disabled(!model.canEditRoomLayout)
                                    Picker("Fixture role", selection: Binding(
                                        get: { placement.role },
                                        set: { role in
                                            model.updateRoomFixture(light.id) {
                                                $0.role = role
                                            }
                                        }
                                    )) {
                                        ForEach(HueFixtureRole.allCases, id: \.self) { role in
                                            Text(role.title).tag(role)
                                        }
                                    }
                                    .disabled(!model.canEditRoomLayout)
                                    Text("Task and background roles hold a steady color. Accent shifts the spatial pattern phase; wash follows the saved path.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    placementSlider(
                                        "Animation phase", id: light.id,
                                        keyPath: \.phase, range: 0...1, percentage: true
                                    )
                                    placementSlider(
                                        "Output trim", id: light.id,
                                        keyPath: \.trim, range: 0.1...1, percentage: true
                                    )
                                    placementSlider(
                                        "Additional ceiling", id: light.id,
                                        keyPath: \.ceiling, range: 5...100, percentage: false
                                    )

                                    placementSlider(
                                        "Position X", id: light.id,
                                        keyPath: \.x, range: 0...1, percentage: true
                                    )
                                    placementSlider(
                                        "Position Y", id: light.id,
                                        keyPath: \.y, range: 0...1, percentage: true
                                    )
                                    LabeledContent("Bridge maximum",
                                        value: "\(Int(light.outputLimit))%")
                                }
                            }
                            .padding(16)
                            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))

                            Button("Reset to evenly spaced ring", role: .destructive) {
                                showResetConfirmation = true
                            }
                            .disabled(!model.canEditRoomLayout)
                            .confirmationDialog(
                                "Replace this room's local positions?",
                                isPresented: $showResetConfirmation
                            ) {
                                Button("Reset local layout", role: .destructive) {
                                    model.resetRoomLayoutToRing()
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("Replaces your locally saved positions, selection, and trims. No lights or Hue Bridge layouts are changed.")
                            }

                            Text("Only selected, eligible non-streaming color lights are controlled by Studio. Before playback, Hue Board captures their restore baseline, uses one writer, and enforces each fixture's minimum and effective ceiling.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ContentUnavailableView(
                                "No room layout",
                                systemImage: "square.grid.3x3",
                                description: Text("Choose a Hue room or zone with lights.")
                            )
                        }
                    }
                    .padding()
                  }
                }
            }
        }
        .sheet(item: $sweepPreview) { RoomSweepSheet(preview: $0) }
        .navigationTitle("Room")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.isSettingsPresented = true } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private func placementSlider(
        _ title: String,
        id: HueResourceID,
        keyPath: WritableKeyPath<HueFixturePlacement, Double>,
        range: ClosedRange<Double>,
        percentage: Bool
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
                    Text("Preview for \(preview.area.name)")
                        .foregroundStyle(.secondary)
                    RoomFixtureMap(
                        area: preview.area,
                        layout: preview.proposedLayout,
                        focusedID: focusedID,
                        isEditable: false,
                        onFocus: { focusedID = $0 },
                        onMove: { _, _, _ in }
                    )
                    Text("Saving changes the matching fixture positions in this room. Your fixture selection, phase, roles, trim and ceilings are preserved.")
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

private struct RoomFixtureMap: View {
    let area: HueArea
    let layout: HueRoomLayout
    let focusedID: HueResourceID?
    let isEditable: Bool
    let onFocus: (HueResourceID) -> Void
    let onMove: (HueResourceID, Double, Double) -> Void

    @State private var previewPositions: [HueResourceID: CGPoint] = [:]

    private let markerSize: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            let inset = markerSize / 2
            let mapSize = CGSize(
                width: max(1, geometry.size.width - markerSize),
                height: max(1, geometry.size.height - markerSize)
            )
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.45))
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
                .stroke(.white.opacity(0.10), lineWidth: 1)

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
                                        focusedID == placement.id ? Color.white : Color.white.opacity(0.3),
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
                        .accessibilityValue(placement.selected ? "Selected for Studio" : "Excluded from Studio")
                        .accessibilityAddTraits(focusedID == placement.id ? [.isSelected] : [])
                        .accessibilityHint("Shows fixture settings and position controls")
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
        .frame(height: 290)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Interactive room fixture map")
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
