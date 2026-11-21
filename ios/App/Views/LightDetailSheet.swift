import SwiftUI
import UIKit
import HueBoardKit

struct LightDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let initialLight: HueLight
    @State private var brightness: Double
    @State private var color: Color
    @State private var temperatureMirek: Double

    init(light: HueLight) {
        initialLight = light
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
        if model.isBusy { return "Wait for the current Bridge operation to finish." }
        if !canEdit { return "Stop and restore playback before editing this light." }
        return nil
    }

    private var powerReadback: String {
        guard light.isOn else { return "Off" }
        guard let level = light.brightness else { return "On" }
        return "\(Self.levelLabel(level)) on"
    }

    var body: some View {
        let powerLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(swiftUIColor(light.colorTemperatureMirek == nil ? light.color : nil))
                            .frame(width: 48, height: 48)
                            .overlay(Circle().stroke(.white.opacity(0.2)))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(light.name).font(.title3.bold())
                            Text(model.isReady && currentLight != nil ? "Bridge readback" : "Last known state")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(powerReadback).font(.subheadline.monospacedDigit())
                            if light.isOn, let mirek = light.colorTemperatureMirek, mirek > 0 {
                                Text("White · \(Self.kelvinLabel(Double(mirek)))")
                                    .font(.caption)
                            } else if light.isOn, light.color != nil {
                                Text("Color").font(.caption)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    if let editingStatus {
                        Text(editingStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Power") {
                    powerLayout {
                        Button("Turn on") {
                            Task { await model.setLightPower(light.id, on: true) }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Turn off") {
                            Task { await model.setLightPower(light.id, on: false) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .disabled(!canEdit || !light.capabilities.power)
                }

                if light.capabilities.dimming {
                    Section("Brightness") {
                        if light.minimumBrightness <= light.outputLimit {
                            brightnessControls(light.minimumBrightness...light.outputLimit)
                        } else {
                            Text("The output ceiling is below this fixture’s reported minimum.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if light.capabilities.color {
                    Section("Color") {
                        ColorPicker("Choose a color", selection: $color, supportsOpacity: false)
                            .disabled(!canEdit)
                        Button("Apply color & turn on") {
                            let converted = UIColor(color)
                            var red: CGFloat = 0
                            var green: CGFloat = 0
                            var blue: CGFloat = 0
                            var alpha: CGFloat = 0
                            guard converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
                                model.errorMessage = "The selected color could not be converted to sRGB."
                                return
                            }
                            let rgb = RGB(
                                red: Double(red),
                                green: Double(green),
                                blue: Double(blue)
                            )
                            Task { await model.setLightColor(light.id, rgb: rgb) }
                        }
                        .disabled(!canEdit)
                    }
                }

                if light.capabilities.colorTemperature {
                    Section("White temperature") {
                        if let range = light.supportedTemperatureRange {
                            temperatureControls(Double(range.lowerBound)...Double(range.upperBound))
                        } else {
                            Text("The Bridge did not report a safe white-temperature range for this fixture.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Safety & recovery") {
                    if light.capabilities.dimming {
                        LabeledContent("Output ceiling", value: Self.levelLabel(light.outputLimit))
                        LabeledContent("Minimum level", value: Self.levelLabel(light.minimumBrightness))
                    }
                    Text("Power and Apply send changes. Hue Board saves the current state for restoration first.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Reset draft") { resetDraft() }
                        .disabled(!model.isReady || currentLight == nil)
                        .accessibilityHint("Uses the latest Bridge readback for the draft controls.")
                }
            }
            .navigationTitle("Individual light")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func brightnessControls(_ range: ClosedRange<Double>) -> some View {
        let value = Binding(
            get: { min(max(brightness, range.lowerBound), range.upperBound) },
            set: { brightness = $0 }
        )
        return Group {
            LabeledContent("Draft brightness", value: Self.levelLabel(value.wrappedValue))
            if range.lowerBound < range.upperBound {
                Slider(value: value, in: range)
                    .accessibilityLabel("Draft brightness")
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
            LabeledContent("Draft white tone", value: Self.kelvinLabel(value.wrappedValue))
            if range.lowerBound < range.upperBound {
                Slider(value: value, in: range, step: 1)
                    .accessibilityLabel("Draft white temperature")
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
