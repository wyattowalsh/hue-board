import SwiftUI
import HueBoardKit

struct CueSequencerSection: View {
    @Environment(AppModel.self) private var model
    @State private var candidateID = ""

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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Cue sequencer", systemImage: "list.number")
                    .font(.headline)
                Spacer()
                Text("\(model.cueIDs.count)/12")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Toggle("Sequence these looks during Studio Live",
                   isOn: $model.isCueSequenceEnabled)
                .disabled(model.isLiveRunning)
            Text("One foreground or system-bounded Studio session. Each cue uses its preset pattern and palette, while retaining master brightness, the selected room layout, and one light writer.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.cueIDs.isEmpty {
                Text("Add a look to begin sequencing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(model.cueIDs.enumerated()), id: \.offset) { index, id in
                HStack(spacing: 8) {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text(model.contract.preset(id: id)?.name ?? "Unknown cue")
                        .font(.subheadline)
                    Spacer()
                    Button {
                        var next = model.cueIDs
                        next.swapAt(index, index - 1)
                        model.cueIDs = next
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(index == 0 || model.isLiveRunning)
                    .accessibilityLabel("Move cue \(index + 1) earlier")

                    Button(role: .destructive) {
                        model.cueIDs.remove(at: index)
                        if model.cueIDs.isEmpty { model.isCueSequenceEnabled = false }
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .disabled(model.isLiveRunning)
                    .accessibilityLabel("Remove cue \(index + 1)")
                }
            }

            if !candidates.isEmpty && model.cueIDs.count < 12 {
                HStack {
                    Picker("Add look", selection: $candidateID) {
                        Text("Choose…").tag("")
                        ForEach(candidates) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    .pickerStyle(.menu)
                    Button("Add") {
                        guard !candidateID.isEmpty,
                              model.contract.preset(id: candidateID) != nil,
                              !model.cueIDs.contains(candidateID),
                              model.cueIDs.count < 12 else { return }
                        model.cueIDs.append(candidateID)
                        candidateID = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(candidateID.isEmpty || model.isLiveRunning)
                }
            }

            HStack {
                Text("Hold each cue")
                Spacer()
                Text("\(Int(model.cueHoldSeconds))s")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $model.cueHoldSeconds, in: 30...600, step: 5)
                .disabled(model.isLiveRunning)
                .accessibilityLabel("Hold each cue")
            Picker("Order", selection: $model.cueOrder) {
                Text("In order").tag(HueCueOrder.forward)
                Text("Seeded shuffle").tag(HueCueOrder.shuffle)
            }
            .pickerStyle(.segmented)
            .disabled(model.isLiveRunning)

            if !isValid && model.isCueSequenceEnabled {
                Label("The cue list is not valid; playback will remain disabled.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let status = model.currentCueStatus {
                Label(status, systemImage: "waveform")
                    .font(.subheadline)
            }
            Text("Cues follow monotonic elapsed session time. If iOS suspends execution, missed cues are skipped without queued catch-up commands. This is low-rate REST, not Entertainment streaming.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
    }
}
