import SwiftUI
import HueBoardKit

struct LiveView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var composeExpanded = true
    @State private var sculptExpanded = true
    @State private var advancedExpanded = false

    private enum StudioSection: String, CaseIterable {
        case preview = "Preview"
        case compose = "Composition"
        case palette = "Palette"
        case cues = "Cues"
        case library = "Saved mixes"
        case playback = "Playback"
    }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.isReady {
                        StatusCard()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Make it move.")
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("Blend two patterns, tune their motion, and preview your composition.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    StudioRehearsalView().id(StudioSection.preview)

                    VStack(spacing: 16) {
                        sourcePresetPicker
                        compositionControls
                    }
                    .id(StudioSection.compose)

                    StudioCustomPaletteSection().id(StudioSection.palette)
                    CueSequencerSection().id(StudioSection.cues)
                    StudioLibrarySection().id(StudioSection.library)
                    playbackControls.id(StudioSection.playback)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Studio")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(StudioSection.allCases, id: \.self) { section in
                            Button(section.rawValue) {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                                    scroll.scrollTo(section, anchor: .top)
                                }
                            }
                        }
                    } label: {
                        Label("Jump to section", systemImage: "list.bullet")
                    }
                    .accessibilityIdentifier("studio-section-jump")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.isSettingsPresented = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }

    }

    private var sourcePresetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start from a look")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .disabled(model.isLiveRunning)
    }

    private var compositionControls: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 12) {
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
    }

    private var playbackControls: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 12) {
            StudioInputPreviewSection()
            StudioSlider(title: "Session duration", value: $model.liveDuration, range: 300...3_600, step: 300, unit: "s")
                .disabled(model.isBusy || model.isLiveRunning)
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
            .accessibilityIdentifier("studio-start")

            if !model.isReady {
                Button("Connect Bridge for Studio Live", systemImage: "dot.radiowaves.left.and.right") {
                    model.presentConnection()
                }
            } else if model.isLiveRunning {
                Text("Studio is running with the captured settings. Stop and restore before starting another session.")
                    .font(.footnote)
            }
            Text("Studio Live sends low-rate Hue transitions. Use Stop & restore to recover your earlier light states.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }


}

private struct StudioSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    private var formattedValue: String {
        value.formatted(.number.precision(.fractionLength(step < 1 ? 2 : 0))) + unit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(formattedValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .accessibilityHidden(true)
            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(formattedValue)
        }
    }
}
