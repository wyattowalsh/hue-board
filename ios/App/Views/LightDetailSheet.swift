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

    init(light: HueLight) {
        initialLight = light
        _brightness = State(initialValue: min(
            max(light.brightness ?? 50, light.minimumBrightness),
            light.outputLimit
        ))
        _color = State(initialValue: swiftUIColor(light.color))
        _temperatureMirek = State(initialValue: Double(
            light.colorTemperatureMirek
                ?? light.supportedTemperatureRange?.lowerBound
                ?? 250
        ))
    }

    private var light: HueLight {
        model.selectedArea?.lights.first(where: { $0.id == initialLight.id })
            ?? initialLight
    }

    private var canEdit: Bool {
        model.canUseEverydayControls && !light.capabilities.streaming
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(swiftUIColor(light.color))
                            .frame(width: 48, height: 48)
                            .overlay(Circle().stroke(.white.opacity(0.2)))
                        VStack(alignment: .leading) {
                            Text(light.name).font(.title3.bold())
                            Text(light.capabilities.streaming ? "Entertainment stream active" : "Bridge readback")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(light.isOn
                                ? (light.brightness.map { "\(Int($0))% on" } ?? "On")
                                : "Off")
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                }

                Section("Power") {
                    HStack(spacing: 12) {
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

                if light.capabilities.dimming,
                   light.minimumBrightness <= light.outputLimit {
                    Section("Brightness") {
                        HStack {
                            Text("Set brightness")
                            Spacer()
                            Text("\(Int(brightness))%").monospacedDigit()
                        }
                        Slider(
                            value: $brightness,
                            in: light.minimumBrightness...light.outputLimit,
                            step: 1
                        )
                        .disabled(!canEdit)
                        Button("Apply brightness & turn on") {
                            Task {
                                await model.setLightBrightness(light.id, value: brightness)
                            }
                        }
                        .disabled(!canEdit)
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
                            HStack {
                                Text("White tone")
                                Spacer()
                                Text("\(Int(1_000_000 / temperatureMirek)) K")
                                    .monospacedDigit()
                            }
                            Slider(
                                value: $temperatureMirek,
                                in: Double(range.lowerBound)...Double(range.upperBound),
                                step: 1
                            )
                            .disabled(!canEdit)
                            HStack {
                                Text("Cooler")
                                Spacer()
                                Text("Warmer")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Button("Apply white & turn on") {
                                Task {
                                    await model.setLightTemperature(
                                        light.id,
                                        mirek: Int(temperatureMirek.rounded())
                                    )
                                }
                            }
                            .disabled(!canEdit)
                        } else {
                            Text("The Bridge did not report a safe white-temperature range for this fixture.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Safety & recovery") {
                    LabeledContent("Output ceiling", value: "\(Int(light.outputLimit))%")
                    LabeledContent("Minimum level", value: "\(light.minimumBrightness.formatted())%")
                    Text("Changes are only sent when you tap a button. Hue Board captures a restorable baseline first, respects reported fixture capabilities, and will not override Entertainment streaming lights.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !canEdit {
                        Text("Editing is unavailable during playback, recovery, or streaming.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
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
}
