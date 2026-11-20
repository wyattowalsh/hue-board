import SwiftUI
import HueBoardKit

struct RoomLayoutView: View {
    @Environment(AppModel.self) private var model
    @State private var showResetConfirmation = false

    private var activePlacement: HueFixturePlacement? {
        model.roomLayout?.placements.first(where: { $0.id == model.focusedFixtureID })
    }

    var body: some View {
        Group {
            if !model.isReady {
                ConnectPrompt()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        StatusCard()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Room, not a list.")
                                .font(.title2.bold())
                            Text("Arrange lights by position and phase. Editing the map never changes your bulbs.")
                                .foregroundStyle(.secondary)
                        }
                        AreaPicker()

                        if let issue = model.roomLayoutIssue {
                            Label(issue, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        } else if let area = model.selectedArea,
                                  let layout = model.roomLayout {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("Spatial map", systemImage: "circle.hexagongrid")
                                        .font(.headline)
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
                                Text("Tap a light to edit it; drag to move it. Positions are local coordinates, not measured distances.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))

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

                                    LabeledContent("Position X",
                                        value: "\(Int(placement.x * 100))%")
                                    LabeledContent("Position Y",
                                        value: "\(Int(placement.y * 100))%")
                                    LabeledContent("Bridge maximum",
                                        value: "\(Int(light.outputLimit))%")
                                }
                            }
                            .padding(16)
                            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
                            .disabled(!model.canEditRoomLayout)

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
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(current * (percentage ? 100 : 1)))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
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
                .accessibilityLabel(title)
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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.45))
                Path { path in
                    for fraction in [0.25, 0.5, 0.75] {
                        path.move(to: CGPoint(x: geometry.size.width * fraction, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width * fraction, y: geometry.size.height))
                        path.move(to: CGPoint(x: 0, y: geometry.size.height * fraction))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * fraction))
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
                                    .fill(swiftUIColor(light.color))
                                Circle()
                                    .stroke(
                                        focusedID == placement.id ? Color.white : Color.white.opacity(0.3),
                                        lineWidth: focusedID == placement.id ? 3 : 1
                                    )
                                Text("\(index + 1)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.black)
                            }
                            .opacity(placement.selected ? 1 : 0.40)
                            .frame(width: 42, height: 42)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(light.name), \(placement.selected ? "selected" : "excluded")")
                        .position(
                            x: point.x * geometry.size.width,
                            y: point.y * geometry.size.height
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .named("room-map"))
                                .onChanged { drag in
                                    guard isEditable else { return }
                                    previewPositions[placement.id] = CGPoint(
                                        x: min(max(drag.location.x / geometry.size.width, 0.04), 0.96),
                                        y: min(max(drag.location.y / geometry.size.height, 0.06), 0.94)
                                    )
                                }
                                .onEnded { drag in
                                    defer { previewPositions.removeValue(forKey: placement.id) }
                                    guard isEditable else { return }
                                    let x = min(max(drag.location.x / geometry.size.width, 0.04), 0.96)
                                    let y = min(max(drag.location.y / geometry.size.height, 0.06), 0.94)
                                    onMove(placement.id, x, y)
                                    onFocus(placement.id)
                                }
                        )
                    }
                }
            }
            .coordinateSpace(name: "room-map")
        }
        .frame(height: 290)
        .accessibilityLabel("Interactive room fixture map")
    }
}
