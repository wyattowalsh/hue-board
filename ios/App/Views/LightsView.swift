import SwiftUI
import HueBoardKit

struct LightsView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedLight: HueLight?

    var body: some View {
        Group {
            if model.isReady {
                List {
                    Section { AreaPicker().accessibilityIdentifier("lights-room-picker") }
                    if let area = model.selectedArea, let profile = model.profile {
                        let scope = LightingScope(bridgeID: profile.bridgeID, areaID: area.id)
                        RoomControls(area: area, scope: scope).id(scope)
                        Section {
                            ForEach(area.lights) { light in
                                Button { selectedLight = light } label: {
                                    HStack {
                                        LightRow(light: light)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                            .accessibilityHidden(true)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Edit \(light.name)")
                                .accessibilityValue(accessibleReadback(light))
                            }
                        } header: {
                            Text("Individual lights (\(area.lights.count))")
                        }
                    } else {
                        ContentUnavailableView("No room selected", systemImage: "lightbulb",
                                               description: Text("Choose a Hue room or zone to control its lights."))
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Refresh lights", systemImage: "arrow.clockwise") {
                                Task { await model.refreshInventory() }
                            }
                            .disabled(model.isBusy)
                            if model.playbackSnapshot.mode == .idle && !model.hasRestorePoint && !model.foreignRecoveryPending {
                                Button("Turn off now", systemImage: "power", role: .destructive) {
                                    Task { await model.turnOffNow() }
                                }
                                .disabled(!model.canTurnOffNow)
                                .accessibilityHint("Interrupts other commands and preserves the lights’ previous settings for restoration.")
                            }
                        } label: {
                            Label("More light controls", systemImage: "ellipsis.circle")
                        }
                        .accessibilityIdentifier("lights-more-actions")
                    }
                }
            } else {
                ConnectPrompt()
            }
        }
        .navigationTitle("Lights")
        .sheet(item: $selectedLight) { light in
            LightDetailSheet(light: light).environment(model)
        }
    }

    private func accessibleReadback(_ light: HueLight) -> String {
        if light.capabilities.streaming { return "Entertainment stream active" }
        if !light.isOn { return "Off" }
        guard let level = light.brightness else { return "On" }
        return "On, \(level.formatted(.number.precision(.fractionLength(0...1)))) percent"
    }
}

private struct RoomControls: View {
    @Environment(AppModel.self) private var model
    let area: HueArea
    let scope: LightingScope
    @State private var roomBrightness: Double
    @State private var feedback: String?

    init(area: HueArea, scope: LightingScope) {
        self.area = area
        self.scope = scope
        _roomBrightness = State(initialValue: area.initialRoomBrightness)
    }

    var body: some View {
        let canPower = area.lights.contains { $0.capabilities.power && !$0.capabilities.streaming }
        let canDim = area.lights.contains(where: \.canSetRoomBrightness)
        Section {
            ViewThatFits(in: .horizontal) {
                HStack { areaPowerButtons }
                VStack(alignment: .leading, spacing: 8) { areaPowerButtons }
            }
            .disabled(!model.canUseEverydayControls || !canPower)
            if canDim {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Brightness", value: roomBrightness / 100, format: .percent.precision(.fractionLength(0)))
                        .accessibilityHidden(true)
                    Slider(value: $roomBrightness, in: 1...100, step: 1)
                        .accessibilityLabel("Area brightness")
                        .accessibilityValue("\(Int(roomBrightness)) percent")
                    Button("Apply brightness & turn on") {
                        let target = roomBrightness
                        feedback = nil
                        Task { feedback = await model.setAreaBrightness(target, in: scope) }
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(!model.canUseEverydayControls)
            }
        } footer: {
            if model.foreignRecoveryPending {
                Text("Reconnect the original Bridge to restore its lights before changing this room.")
            } else if !canPower && !canDim {
                Text("This room has no lights available to control.")
            } else if let feedback {
                Text(feedback).accessibilityIdentifier("lights-room-feedback")
            }
        }
    }

    @ViewBuilder private var areaPowerButtons: some View {
        Button("Turn on") {
            feedback = nil
            Task { feedback = await model.setAreaPower(true, in: scope) }
        }
        .buttonStyle(.bordered)
        Button("Turn off") {
            feedback = nil
            Task { feedback = await model.setAreaPower(false, in: scope) }
        }
        .buttonStyle(.bordered)
    }
}
