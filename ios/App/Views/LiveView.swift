import SwiftUI
import HueBoardKit

struct LiveView: View {
    @Environment(AppModel.self) private var model
    @State private var composeExpanded = true
    @State private var sculptExpanded = true
    @State private var advancedExpanded = false

    var body: some View {
        @Bindable var model = model

        Group {
            if !model.isReady {
                ConnectPrompt()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        StatusCard()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Make it move.")
                                .font(.largeTitle.bold())
                            Text("Shape two patterns into your own composition. Editing is a preview; nothing is sent to the lights until you press Start.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        StudioEnginePreview()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Start from a look")
                                .font(.headline)
                            Picker("Source preset", selection: Binding(
                                get: { model.selectedPresetID },
                                set: { id in
                                    if let preset = model.contract.preset(id: id) {
                                        model.loadPresetIntoStudio(preset)
                                    }
                                }
                            )) {
                                ForEach(model.contract.presets) { preset in
                                    Text(preset.name).tag(preset.id)
                                }
                            }
                            .pickerStyle(.menu)
                            Text("Loading a look replaces your unsaved Studio edits.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .disabled(model.isLiveRunning)

                        VStack(alignment: .leading, spacing: 12) {
                            StudioSlider(title: "Master brightness", value: $model.brightness, range: 5...100, step: 1, unit: "%")
                            Text("Maximum dynamic brightness: \(Int(model.safetySettings.maximumDynamicBrightness))% · adjustable in Settings")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if model.brightness > model.effectiveDynamicBrightness {
                                Label("Physical-light safety caps playback at \(Int(model.effectiveDynamicBrightness))%.", systemImage: "shield.lefthalf.filled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            DisclosureGroup("Compose A / B looks", isExpanded: $composeExpanded) {
                                VStack(alignment: .leading, spacing: 14) {
                                    Picker("Pattern A", selection: $model.studioSettings.showA) {
                                        ForEach(model.contract.patterns) { pattern in
                                            Text(pattern.name).tag(pattern.id)
                                        }
                                    }
                                    Picker("Palette A", selection: $model.studioSettings.paletteA) {
                                        ForEach(model.contract.palettes) { palette in
                                            Text(palette.name).tag(palette.index)
                                        }
                                    }
                                    Picker("Pattern B", selection: $model.studioSettings.showB) {
                                        ForEach(model.contract.patterns) { pattern in
                                            Text(pattern.name).tag(pattern.id)
                                        }
                                    }
                                    Picker("Palette B", selection: $model.studioSettings.paletteB) {
                                        ForEach(model.contract.palettes) { palette in
                                            Text(palette.name).tag(palette.index)
                                        }
                                    }
                                    StudioSlider(title: "Blend A → B", value: $model.studioSettings.morph, range: 0...100, step: 1, unit: "%")
                                }
                                .padding(.top, 12)
                            }
                            .font(.headline)

                            DisclosureGroup("Sculpt the motion", isExpanded: $sculptExpanded) {
                                VStack(spacing: 14) {
                                    StudioSlider(title: "Energy", value: $model.studioSettings.energy, range: 0...100, step: 1, unit: "%")
                                    StudioSlider(title: "Motion speed", value: $model.studioSettings.speed, range: 0.25...1.6, step: 0.05, unit: "×")
                                    StudioSlider(title: "Contrast / depth", value: $model.studioSettings.depth, range: 0...100, step: 1, unit: "%")
                                    StudioSlider(title: "Focus", value: $model.studioSettings.focus, range: 0...100, step: 1, unit: "%")
                                    StudioSlider(title: "Tension", value: $model.studioSettings.tension, range: 0...100, step: 1, unit: "%")
                                }
                                .padding(.top, 12)
                            }
                            .font(.headline)

                            DisclosureGroup("Fine control", isExpanded: $advancedExpanded) {
                                VStack(spacing: 14) {
                                    StudioSlider(title: "Motif width", value: $model.studioSettings.spread, range: 0.5...2, step: 0.05, unit: "×")
                                    StudioSlider(title: "Atmosphere floor", value: $model.studioSettings.ambientFloor, range: 0...65, step: 1, unit: "%")
                                    StudioSlider(title: "Accent amount", value: $model.studioSettings.accentMix, range: 0...100, step: 1, unit: "%")
                                    Picker("Path topology", selection: $model.studioSettings.topology) {
                                        Text("Closed ring").tag("ring")
                                        Text("Open path").tag("path")
                                    }
                                    Toggle("Reverse direction", isOn: $model.studioSettings.reverse)
                                }
                                .padding(.top, 12)
                            }
                            .font(.headline)
                        }
                        .padding(16)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
                        .disabled(model.isLiveRunning)

                        StudioCustomPaletteSection()
                        CueSequencerSection()
                        StudioLibrarySection()

                        VStack(alignment: .leading, spacing: 12) {
                            StudioSlider(title: "Session duration", value: $model.liveDuration, range: 300...3_600, step: 300, unit: "s")
                            Button {
                                Task { await model.startNativeLive() }
                            } label: {
                                Label(
                                    model.isCueSequenceEnabled ? "Start cue sequence" : "Start Studio Live",
                                    systemImage: "waveform.path"
                                )
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(!model.canStartLive)

                            if model.isLiveRunning {
                                Text("Studio is running with the captured settings. Stop and restore before starting another session.")
                                    .font(.footnote)
                            }
                            Text("This runs the shared pattern engine over bounded, low-rate Hue REST transitions. Bridge Play is a separate, phone-free dynamic palette, not the exact Studio choreography. Use Stop & restore to recover your earlier light states.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Studio")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.isSettingsPresented = true } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
            }
        }
    }
}

private struct StudioSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(value.formatted(.number.precision(.fractionLength(step < 1 ? 2 : 0))) + unit)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(title)
        }
    }
}

private struct StudioEnginePreview: View {
    @Environment(AppModel.self) private var model
    @State private var frames: [HueLightFrame] = []

    private var previewSettings: HueEngineSettings {
        var draft = model.studioSettings
        draft.brightness = model.effectiveDynamicBrightness
        return PhysicalLightSafetyPolicy.adjustedEngineSettings(
            draft, safety: model.safetySettings
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Engine preview", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("No light writes")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    let frame = index < frames.count ? frames[index] : nil
                    RoundedRectangle(cornerRadius: 7)
                        .fill(frame.map {
                            Color(
                                red: min(max($0.color.red, 0), 1),
                                green: min(max($0.color.green, 0), 1),
                                blue: min(max($0.color.blue, 0), 1)
                            )
                        } ?? Color.secondary.opacity(0.25))
                        .frame(maxWidth: .infinity)
                        .frame(height: frame.map { max(12, min(100, $0.brightness)) } ?? 16)
                }
            }
            .frame(height: 112, alignment: .bottom)
            Text("Sampled from the actual shared engine at one moment. Not a prediction of physical output or animation smoothness.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.22),
                    Color(red: 0.08, green: 0.09, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .foregroundStyle(.white)
        .task(id: previewSettings) {
            let settings = previewSettings
            var next: [HueLightFrame] = []
            for index in 0..<12 {
                if Task.isCancelled { return }
                do {
                    next.append(try await model.engine.sample(
                        time: 19,
                        position: Double(index) / 12,
                        settings: settings,
                        surge: 0
                    ))
                } catch {
                    frames = []
                    return
                }
            }
            if !Task.isCancelled { frames = next }
        }
    }
}
