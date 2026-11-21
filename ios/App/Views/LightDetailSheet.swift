import SwiftUI
import UIKit
import HueBoardKit

struct LightDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let initialLight: HueLight
    @State private var brightness: Double
    @State private var color: Color
    @State private var temperatureMirek: Double
    @State private var whiteMode: Bool

    init(light: HueLight) {
        initialLight = light
        _whiteMode = State(initialValue: light.colorTemperatureMirek != nil)
        _brightness = State(initialValue: light.brightness ?? 50)
        _color = State(initialValue: swiftUIColor(light.color))
        _temperatureMirek = State(initialValue: Double(
            light.colorTemperatureMirek ?? light.supportedTemperatureRange?.lowerBound ?? 250
        ))
    }

    private var currentLight: HueLight? {
        model.selectedArea?.lights.first { $0.id == initialLight.id }
    }

    private var light: HueLight {
        currentLight ?? initialLight
    }

    private var canEdit: Bool {
        model.canUseEverydayControls && currentLight != nil && !light.capabilities.streaming
    }

    private var editingStatus: String? {
        if !model.isReady { return "Reconnect the Bridge to edit this light." }
        if currentLight == nil { return "This light is no longer in the selected room or zone." }
        if light.capabilities.streaming { return "An Entertainment stream controls this light." }
        if model.foreignRecoveryPending { return "Reconnect the original Bridge to restore its lights." }
        if let issue = model.setupStorageIssue { return issue }
        if model.isBusy { return "Updating lights…" }
        if !canEdit { return "Stop and restore playback before editing this light." }
        return nil
    }

    private var powerReadback: String {
        guard light.isOn else { return "Off" }
        guard let level = light.brightness else { return "On" }
        return "On · \(Self.levelLabel(level))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(model.isReady && currentLight != nil ? "Current state" : "Last known state",
                                   value: powerReadback)
                    if light.capabilities.power {
                        let turnOn = !light.isOn
                        Button(turnOn ? "Turn on" : "Turn off") {
                            Task { await model.setLightPower(light.id, on: turnOn) }
                        }
                        .disabled(!canEdit)
                    }
                } footer: {
                    if let editingStatus { Text(editingStatus) }
                }

                if light.capabilities.dimming {
                    Section("Brightness") {
                        if light.minimumBrightness <= light.outputLimit {
                            brightnessControls(light.minimumBrightness...light.outputLimit)
                        } else {
                            Text("The brightness limit is below this light’s minimum.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if light.capabilities.color || light.capabilities.colorTemperature {
                    Section("Light color") {
                        if light.capabilities.color && light.capabilities.colorTemperature {
                            Picker("Color mode", selection: $whiteMode) {
                                Text("Color").tag(false)
                                Text("White").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                        if light.capabilities.colorTemperature && (whiteMode || !light.capabilities.color) {
                            if let range = light.supportedTemperatureRange {
                                temperatureControls(Double(range.lowerBound)...Double(range.upperBound))
                            } else {
                                Text("This light hasn’t reported its supported white-temperature range.")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ColorPicker("Color", selection: $color, supportsOpacity: false)
                                .disabled(!canEdit)
                            Button("Apply color & turn on", action: applyColor)
                                .disabled(!canEdit)
                        }
                    }
                }

                Section {
                    DisclosureGroup("Light details") {
                        if light.capabilities.dimming {
                            LabeledContent("Brightness limit", value: Self.levelLabel(light.outputLimit))
                            LabeledContent("Minimum brightness", value: Self.levelLabel(light.minimumBrightness))
                        }
                        if let mirek = light.colorTemperatureMirek, mirek > 0 {
                            LabeledContent("White temperature", value: Self.kelvinLabel(Double(mirek)))
                        }
                        Button("Reset edits to current state") { resetDraft() }
                            .disabled(!model.isReady || currentLight == nil)
                    }
                }
            }
            .navigationTitle(light.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("light-detail-done")
                }
            }
        }
    }

    private func applyColor() {
        let converted = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            model.errorMessage = "The selected color could not be converted to sRGB."
            return
        }
        let rgb = RGB(red: Double(red), green: Double(green), blue: Double(blue))
        Task { await model.setLightColor(light.id, rgb: rgb) }
    }

    private func brightnessControls(_ range: ClosedRange<Double>) -> some View {
        let value = Binding(
            get: { min(max(brightness, range.lowerBound), range.upperBound) },
            set: { brightness = $0 }
        )
        return Group {
            LabeledContent("Level", value: Self.levelLabel(value.wrappedValue))
            if range.lowerBound < range.upperBound {
                Slider(value: value, in: range)
                    .accessibilityLabel("Brightness")
                    .accessibilityValue(Text(Self.levelLabel(value.wrappedValue)))
            }
            Button("Apply brightness & turn on") {
                let level = value.wrappedValue
                Task { await model.setLightBrightness(light.id, value: level) }
            }
        }
        .disabled(!canEdit)
    }

    private func temperatureControls(_ range: ClosedRange<Double>) -> some View {
        let value = Binding(
            get: { min(max(temperatureMirek, range.lowerBound), range.upperBound) },
            set: { temperatureMirek = $0 }
        )
        return Group {
            LabeledContent("Temperature", value: Self.kelvinLabel(value.wrappedValue))
            if range.lowerBound < range.upperBound {
                Slider(value: value, in: range, step: 1)
                    .accessibilityLabel("White temperature")
                    .accessibilityValue("\(Int(1_000_000 / value.wrappedValue)) kelvin")
                HStack {
                    Text("Cooler")
                    Spacer()
                    Text("Warmer")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            }
            Button("Apply white & turn on") {
                let mirek = Int(value.wrappedValue.rounded())
                Task { await model.setLightTemperature(light.id, mirek: mirek) }
            }
        }
        .disabled(!canEdit)
    }

    private func resetDraft() {
        guard let currentLight else { return }
        whiteMode = currentLight.colorTemperatureMirek != nil
        if let level = currentLight.brightness {
            brightness = level
        }
        if let xy = currentLight.color {
            color = swiftUIColor(xy)
        }
        if let mirek = currentLight.colorTemperatureMirek {
            temperatureMirek = Double(mirek)
        }
    }

    private static func levelLabel(_ level: Double) -> String {
        "\(level.formatted(.number.precision(.fractionLength(0...1))))%"
    }

    private static func kelvinLabel(_ mirek: Double) -> String {
        "\(Int(1_000_000 / mirek)) K"
    }
}
