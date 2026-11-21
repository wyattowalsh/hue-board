import SwiftUI
import HueBoardKit

struct CueSequencerSection: View {
    @Environment(AppModel.self) private var model

    private var candidates: [HuePreset] {
        model.contract.presets.filter { !model.cueIDs.contains($0.id) }
    }

    private var isValid: Bool {
        (try? HueCueSequence(
            presetIDs: model.cueIDs,
            holdSeconds: model.cueHoldSeconds,
            order: model.cueOrder,
            seed: model.studioSettings.seed
        ).validate(contract: model.contract)) != nil
    }

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Scenes · \(model.cueIDs.count) of 12") {
                ForEach(Array(model.cueIDs.enumerated()), id: \.element) { index, id in
                    let name = model.contract.preset(id: id)?.name ?? "Unknown scene"
                    HStack {
                        Text("\(index + 1).")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .accessibilityHidden(true)
                        Text(name)
                            .accessibilityLabel("Cue \(index + 1), \(name)")
                        Spacer()
                        Menu {
                            Button("Move earlier", systemImage: "arrow.up") { move(id, by: -1) }
                                .disabled(index == 0)
                            Button("Move later", systemImage: "arrow.down") { move(id, by: 1) }
                                .disabled(index == model.cueIDs.count - 1)
                            Button("Remove cue", systemImage: "minus.circle", role: .destructive) {
                                model.cueIDs.removeAll { $0 == id }
                                if model.cueIDs.isEmpty { model.isCueSequenceEnabled = false }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Actions for cue \(index + 1), \(name)")
                        .disabled(model.isLiveRunning)
                    }
                }

                if !candidates.isEmpty && model.cueIDs.count < 12 {
                    Menu("Add scene", systemImage: "plus") {
                        ForEach(candidates) { scene in
                            Button(scene.name) {
                                guard !model.isLiveRunning, model.cueIDs.count < 12,
                                      !model.cueIDs.contains(scene.id) else { return }
                                model.cueIDs.append(scene.id)
                            }
                        }
                    }
                    .disabled(model.isLiveRunning)
                    .accessibilityIdentifier("studio-add-cue")
                }
            }

            if !model.cueIDs.isEmpty || model.isCueSequenceEnabled {
                Section {
                    Toggle("Use sequence for playback", isOn: $model.isCueSequenceEnabled)
                        .disabled(model.isLiveRunning || (!isValid && !model.isCueSequenceEnabled))
                    Picker("Order", selection: $model.cueOrder) {
                        Text("In order").tag(HueCueOrder.forward)
                        Text("Shuffle").tag(HueCueOrder.shuffle)
                    }
                    StudioSlider(title: "Time per cue", value: $model.cueHoldSeconds, range: 30...600, step: 5, unit: "s")
                }
                .disabled(model.isLiveRunning)
            }
            if !isValid && model.isCueSequenceEnabled {
                Label("Fix the cue list to enable playback.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if let status = model.currentCueStatus {
                Label(status, systemImage: "waveform")
            }
        }
        .navigationTitle("Cue sequence")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func move(_ id: String, by offset: Int) {
        guard !model.isLiveRunning, let index = model.cueIDs.firstIndex(of: id) else { return }
        let destination = index + offset
        guard model.cueIDs.indices.contains(destination) else { return }
        model.cueIDs.swapAt(index, destination)
    }
}
