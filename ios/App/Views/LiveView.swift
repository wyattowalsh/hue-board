import SwiftUI
import HueBoardKit

struct LiveView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                StudioRehearsalView()
                    .padding(.vertical, 8)
            }

            Section {
                NavigationLink(value: AppModel.StudioDestination.mix) {
                    Label("Edit mix", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("studio-edit-mix")

                NavigationLink(value: AppModel.StudioDestination.cues) {
                    LabeledContent {
                        if model.isCueSequenceEnabled {
                            Text(model.cueIDs.count == 1 ? "1 cue" : "\(model.cueIDs.count) cues")
                        }
                    } label: {
                        Label("Cue sequence", systemImage: "list.number")
                    }
                }
                .accessibilityIdentifier("studio-cues")

                NavigationLink(value: AppModel.StudioDestination.library) {
                    Label("Saved mixes", systemImage: "square.stack")
                }
                .accessibilityIdentifier("studio-library")
            }

            Section {
                NavigationLink(value: AppModel.StudioDestination.playback) {
                    Label("Inputs & playback", systemImage: "lightbulb.2")
                }
                .accessibilityIdentifier("studio-playback")
            }
        }
        .navigationTitle("Studio")
        .navigationDestination(for: AppModel.StudioDestination.self) { destination in
            switch destination {
            case .mix: mixEditor
            case .cues: CueSequencerSection()
            case .library: StudioLibrarySection()
            case .playback: playback
            }
        }
    }

    private var mixEditor: some View {
        @Bindable var model = model
        return Form {
            Section {
                sourcePresetPicker
            } footer: {
                Text("Choosing a scene replaces the current mix settings.")
            }

            Section {
                StudioSlider(title: "Brightness", value: $model.brightness, range: 5...100, step: 1, unit: "%")
                if model.brightness > model.effectiveDynamicBrightness {
                    Label("Playback is limited to \(Int(model.effectiveDynamicBrightness))% by your safety settings.", systemImage: "shield")
                        .font(.footnote)
                }
            }

            Section("Pattern A") {
                patternPicker(selection: $model.studioSettings.showA)
                palettePicker(selection: $model.studioSettings.paletteA)
            }

            Section("Pattern B") {
                patternPicker(selection: $model.studioSettings.showB)
                palettePicker(selection: $model.studioSettings.paletteB)
            }

            Section {
                StudioSlider(title: "Blend toward B", value: $model.studioSettings.morph, range: 0...100, step: 1, unit: "%")
                NavigationLink("Custom palette") { StudioCustomPaletteSection().mixPreviewInset() }
                    .accessibilityIdentifier("studio-palette")
                NavigationLink("Motion and direction") { motionEditor }
            }
        }
        .disabled(model.isLiveRunning)
        .mixPreviewInset()
        .navigationTitle("Edit mix")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sourcePresetPicker: some View {
        let matchingPresetID = model.selectedPreset.flatMap { preset -> String? in
            let settings = HueEngineSettings.from(preset: preset, brightness: model.studioSettings.brightness)
            return model.studioSettings == settings ? preset.id : nil
        }
        return Picker("Scene preset", selection: Binding<String?>(
            get: { matchingPresetID },
            set: { id in
                if let id, let preset = model.contract.preset(id: id) {
                    model.loadPresetIntoStudio(preset)
                }
            }
        )) {
            if matchingPresetID == nil {
                Text("Custom mix").tag(nil as String?)
            }
            ForEach(model.contract.presets) { preset in
                Text(preset.name).tag(Optional(preset.id))
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("studio-source-look")
    }

    private func patternPicker(selection: Binding<String>) -> some View {
        Picker("Pattern", selection: selection) {
            ForEach(model.contract.patterns) { pattern in
                Text(pattern.name).tag(pattern.id)
            }
        }
    }

    private func palettePicker(selection: Binding<Int>) -> some View {
        Picker("Palette", selection: selection) {
            ForEach(model.contract.palettes) { palette in
                Text(palette.name).tag(palette.index)
            }
        }
    }

    private var motionEditor: some View {
        @Bindable var model = model
        return Form {
            Section("Movement") {
                StudioSlider(title: "Speed", value: $model.studioSettings.speed, range: 0.25...1.6, step: 0.05, unit: "×")
                Picker("Path", selection: $model.studioSettings.topology) {
                    Text("Ring").tag("ring")
                    Text("Open path").tag("path")
                }
                Toggle("Reverse direction", isOn: $model.studioSettings.reverse)
            }
            Section("Pattern intensity") {
                StudioSlider(title: "Energy", value: $model.studioSettings.energy, range: 0...100, step: 1, unit: "%")
                StudioSlider(title: "Contrast", value: $model.studioSettings.depth, range: 0...100, step: 1, unit: "%")
                StudioSlider(title: "Focus", value: $model.studioSettings.focus, range: 0...100, step: 1, unit: "%")
                StudioSlider(title: "Tension", value: $model.studioSettings.tension, range: 0...100, step: 1, unit: "%")
                StudioSlider(title: "Pattern width", value: $model.studioSettings.spread, range: 0.5...2, step: 0.05, unit: "×")
                StudioSlider(title: "Background level", value: $model.studioSettings.ambientFloor, range: 0...65, step: 1, unit: "%")
                StudioSlider(title: "Accent amount", value: $model.studioSettings.accentMix, range: 0...100, step: 1, unit: "%")
            }
        }
        .disabled(model.isLiveRunning)
        .mixPreviewInset()
        .navigationTitle("Motion and direction")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var playback: some View {
        @Bindable var model = model
        let durations = (1...12).map { Double($0 * 300) }
        return Form {
            if model.isReady {
                Section {
                    AreaPicker()
                }
            }

            Section {
                StudioInputPreviewSection()
            }
            if !model.studioInputPreview.isIdle {
                Section {
                    StudioRehearsalView()
                }
            }

            Section {
                Picker("Duration", selection: $model.liveDuration) {
                    ForEach(durations, id: \.self) { duration in
                        Text("\(Int(duration / 60)) min").tag(duration)
                    }
                    if model.liveDuration.isFinite, !durations.contains(model.liveDuration) {
                        Text("\(model.liveDuration.formatted(.number.precision(.fractionLength(0...15)))) seconds").tag(model.liveDuration)
                    }
                }
                .disabled(model.isBusy || model.isLiveRunning)
                Button {
                    Task { await model.startNativeLive() }
                } label: {
                    Label(model.isCueSequenceEnabled ? "Play cues on lights" : "Play mix on lights",
                          systemImage: "play.fill")
                }
                .disabled(!model.canStartLive)
                .accessibilityIdentifier("studio-start")
                if !model.isReady {
                    Button("Connect Hue Bridge") { model.presentConnection() }
                }
            }
        }
        .navigationTitle("Inputs & playback")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.studioInputPreview.stop() }
    }
}

private extension View {
    func mixPreviewInset() -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            MixPreview()
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
        }
    }
}

private struct MixPreview: View {
    @Environment(AppModel.self) private var model
    @State private var frames: [HueLightFrame] = []
    @State private var failed = false

    var body: some View {
        let settings = previewSettings
        LabeledContent("Mix preview") {
            if failed {
                Text("Unavailable")
            } else if frames.isEmpty {
                ProgressView()
            } else {
                LinearGradient(colors: frames.map(displayColor), startPoint: .leading, endPoint: .trailing)
                    .frame(maxWidth: 180)
                    .frame(height: 20)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(.secondary.opacity(0.3)))
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mix preview")
        .accessibilityValue(accessibleLevel)
        .accessibilityIdentifier("studio-mix-preview")
        .task(id: settings) {
            do {
                try await Task.sleep(for: .milliseconds(100))
                var next: [HueLightFrame] = []
                for index in 0..<8 {
                    try Task.checkCancellation()
                    next.append(try await model.engine.sample(
                        time: 19, position: Double(index) / 8, settings: settings, surge: 0
                    ))
                }
                try Task.checkCancellation()
                frames = next
                failed = false
            } catch {
                guard !Task.isCancelled else { return }
                frames = []
                failed = true
            }
        }
    }

    private var previewSettings: HueEngineSettings {
        var settings = model.studioSettings
        settings.brightness = model.brightness
        return PhysicalLightSafetyPolicy.adjustedEngineSettings(settings, safety: model.effectiveSafetySettings)
    }

    private func displayColor(_ frame: HueLightFrame) -> Color {
        let level = min(max(frame.brightness / 100, 0), 1)
        return Color(red: frame.color.red * level, green: frame.color.green * level, blue: frame.color.blue * level)
    }

    private var accessibleLevel: String {
        let levels = frames.map { Int($0.brightness.rounded()) }
        guard let low = levels.min(), let high = levels.max() else { return failed ? "Unavailable" : "Loading" }
        return low == high ? "Brightness \(low) percent" : "Brightness \(low) to \(high) percent"
    }
}

struct StudioSlider: View {
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
            LabeledContent(title, value: formattedValue)
                .monospacedDigit()
                .accessibilityHidden(true)
            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(formattedValue)
        }
    }
}
