import SwiftUI

struct LiveView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if !model.isReady {
                ConnectPrompt()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        StatusCard()
                        Text("Ambient Live")
                            .font(.largeTitle.bold())
                        Text(
                            "Samples Hue Board’s shared pattern engine on this iPhone and sends conservative, long REST transitions. Sessions are bounded and interruptible; high-rate choreography requires a future Hue Entertainment transport."
                        )
                        .foregroundStyle(.secondary)

                        Picker("Look", selection: $model.selectedPresetID) {
                            ForEach(model.contract.presets) { preset in
                                Text(preset.name).tag(preset.id)
                            }
                        }
                        .pickerStyle(.navigationLink)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Duration")
                                Spacer()
                                Text(durationText).monospacedDigit()
                            }
                            Slider(value: $model.liveDuration, in: 5 * 60...60 * 60, step: 5 * 60)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Brightness")
                                Spacer()
                                Text("\(Int(model.brightness))%").monospacedDigit()
                            }
                            Slider(value: $model.brightness, in: 5...100, step: 1)
                        }

                        if let preset = model.selectedPreset {
                            ScenePreview(preset: preset, contract: model.contract, selected: true)
                        }

                        Button {
                            Task { await model.startNativeLive() }
                        } label: {
                            Label("Start Ambient Live", systemImage: "waveform.path")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!model.canStartLive)

                        if #unavailable(iOS 26.0) {
                            Text("Ambient Live is foreground-only on this iOS version. Use Play on Bridge for reliable phone-free playback.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Text(
                            "Ambient Live is a low-rate fallback and not Hue Entertainment streaming. iOS continued processing is bounded, visible to the user, and may be queued, cancelled, or expired by the system. Force-quitting ends it."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Live")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.isSettingsPresented = true } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private var durationText: String {
        let minutes = Int(model.liveDuration) / 60
        return minutes == 60 ? "1 hour" : "\(minutes) min"
    }
}
