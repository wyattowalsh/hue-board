import SwiftUI

struct LiveView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Native Live").font(.headline)
                        Text("Runs Hue Board’s exact shared pattern engine on this iPhone. Unlike Play, it continuously sends updates and is bounded and interruptible.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(Color.accentColor)
                }
            }

            Section("Look") {
                Picker("Preset", selection: $model.selectedPresetID) {
                    ForEach(model.contract.presets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                if let preset = model.selectedPreset {
                    HStack(spacing: 12) {
                        SceneSwatch(preset: preset, contract: model.contract)
                            .frame(width: 84, height: 58)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.name).font(.headline)
                            Text(preset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }

            Section("Session") {
                Picker("Duration", selection: $model.liveDuration) {
                    Text("5 minutes").tag(TimeInterval(5 * 60))
                    Text("15 minutes").tag(TimeInterval(15 * 60))
                    Text("30 minutes").tag(TimeInterval(30 * 60))
                }
                ProgressView(value: model.liveProgress)
                    .opacity(model.liveProgress > 0 ? 1 : 0.4)
                    .accessibilityValue("\(Int(model.liveProgress * 100)) percent")

                Button {
                    Task { await model.startNativeLive() }
                } label: {
                    Label("Start Native Live", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canStartLive)

                Button(role: .destructive) {
                    Task { await model.stopAndRestore() }
                } label: {
                    Label("Stop & restore baseline", systemImage: "arrow.uturn.backward.circle")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!model.hasRestorePoint)
            }

            Section("Background behavior") {
                if #available(iOS 26.0, *) {
                    Label("A user-started session requests system continued processing automatically. iOS displays progress and can cancel or expire it.", systemImage: "iphone.and.arrow.forward")
                } else {
                    Label("Native Live is foreground-only on this iOS version. Use Play for phone-free Bridge playback.", systemImage: "iphone")
                }
                Text("Force-quitting Hue Board ends continued processing. Play remains the reliable phone-free mode because the Bridge owns it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Live")
    }
}
