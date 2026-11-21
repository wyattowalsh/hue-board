import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    private var bridgeStatus: String {
        switch model.connectionState {
        case .ready: "Connected"
        case .connecting: "Connecting…"
        case .discovering: "Searching…"
        case .probing: "Verifying…"
        case .awaitingBridgeButton: "Pairing required"
        case .disconnected: model.profile == nil ? "Connect" : "Disconnected"
        }
    }

    var body: some View {
        Form {
            Section {
                Button {
                    model.presentConnection()
                } label: {
                    LabeledContent {
                        Text(bridgeStatus)
                    } label: {
                        Label("Hue Bridge", systemImage: "network")
                    }
                }
                .accessibilityIdentifier("settings-bridge")

                NavigationLink {
                    PlaybackLimitsView()
                } label: {
                    Label("Playback limits", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("settings-playback-limits")
            }
            PortableDataSection()
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { model.isSettingsPresented = false }
            }
        }
    }
}

private struct PlaybackLimitsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Toggle("Reduce Light Motion", isOn: Binding(
                    get: { model.safetySettings.reduceLightMotion },
                    set: { value in Task { await model.setReduceLightMotion(value) } }
                ))
                .disabled(!model.canEditPhysicalSafetySettings)
                if model.systemLightMotion.isEnabled {
                    Label("Dim Flashing Lights is enabled in iOS.", systemImage: "iphone")
                        .font(.footnote)
                }
            } footer: {
                Text("Slows transitions and limits movement during playback. A scene running on the Bridge can still change colors.")
            }

            Section {
                LabeledContent("Maximum brightness", value: brightness)
                    .accessibilityHidden(true)
                Slider(value: Binding(
                    get: { model.safetySettings.maximumDynamicBrightness },
                    set: { value in Task { await model.setMaximumDynamicBrightness(value) } }
                ), in: 10...100, step: 5)
                .accessibilityLabel("Maximum playback brightness")
                .accessibilityValue(brightness)
                .disabled(!model.canEditPhysicalSafetySettings)
            } footer: {
                Text("Applies to new playback sessions. Lower limits set for individual lights still apply.")
            }

            Section {
                if model.safetySettings.warningAcknowledged {
                    Button("Show warning before next playback") {
                        Task { await model.showDynamicLightSafetyAgain() }
                    }
                    .disabled(!model.canEditPhysicalSafetySettings)
                } else {
                    Label("Warning will appear before playback", systemImage: "checkmark")
                }
            } footer: {
                Text("Reduced motion is not a medical guarantee. Stop playback if anyone feels discomfort.")
            }

            if model.isLiveRunning || model.playbackSnapshot.mode == .bridge || model.requiresRecovery {
                Text("Stop and restore playback before changing these limits.")
                    .font(.footnote)
            } else if let issue = model.setupStorageIssue {
                Text(issue).font(.footnote)
            }
        }
        .navigationTitle("Playback limits")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var brightness: String {
        "\(Int(model.safetySettings.maximumDynamicBrightness))%"
    }
}
