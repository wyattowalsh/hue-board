import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section("Bridge") {
                LabeledContent("Status", value: model.isReady ? "Connected" : "Disconnected")
                if let profile = model.profile {
                    LabeledContent("Address", value: profile.displayHost)
                    LabeledContent("Bridge ID", value: profile.bridgeID)
                    if let api = profile.apiVersion { LabeledContent("API", value: api) }
                    if let certificate = profile.displayCertificateSHA256 {
                        LabeledContent("Certificate") {
                            Text(certificate)
                                .font(.caption2.monospaced())
                                .multilineTextAlignment(.trailing)
                                .textSelection(.enabled)
                        }
                    }
                }
                LabeledContent("Push updates", value: model.eventStreamStatus)
                if let lastEventAt = model.lastEventAt {
                    LabeledContent(
                        "Last event",
                        value: lastEventAt.formatted(date: .abbreviated, time: .standard)
                    )
                }
                Button {
                    model.isConnectionSheetPresented = true
                } label: {
                    Label(model.isReady ? "Review connection" : "Connect Bridge", systemImage: "network")
                }
                Button(role: .destructive) {
                    Task { await model.forgetBridge() }
                } label: {
                    Label("Forget Bridge on this device", systemImage: "trash")
                }
                .disabled(!model.canForgetBridge)
            }

            Section("Playback model") {
                Label("Play delegates to a native Hue Bridge dynamic scene and continues without the phone.", systemImage: "antenna.radiowaves.left.and.right")
                Label("Native Live executes the shared Hue Board engine for a bounded user-started session.", systemImage: "waveform.path")
                Label("Stop & restore uses a timestamped static baseline captured before playback.", systemImage: "arrow.uturn.backward")
            }

            Section("Safety") {
                Text("Hue Board verifies that the Bridge API identity matches its local TLS certificate, pins the leaf SHA-256 after first verification, rejects redirects, and stores the application key separately in Keychain.")
                Text("The pin is trust on first use. Verify initial pairing on a trusted home network. A later certificate change fails closed and requires deliberate re-verification.")
                Text("Bridge acknowledgements, push events, and API readback are not optical measurements. Another Hue controller can still change the same lights.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Section("Build") {
                LabeledContent("Native app", value: "0.1.0 vertical slice")
                LabeledContent("Shared contract", value: model.contract.release)
                LabeledContent("Patterns", value: "\(model.contract.patterns.count)")
                LabeledContent("Looks", value: "\(model.contract.presets.count)")
                LabeledContent("Parity frames", value: "512")
            }
        }
        .navigationTitle("Settings")
    }
}
