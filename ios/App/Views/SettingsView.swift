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
                Text("The native transport accepts private-LAN Bridge hosts, rejects HTTP redirects, relies on standard HTTPS trust, and stores the application key in Keychain.")
                Text("Bridge acknowledgements and API readback are not optical measurements. Another Hue controller can still change the same lights.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Section("Build") {
                LabeledContent("Native app", value: "0.1.0 vertical slice")
                LabeledContent("Shared contract", value: model.contract.release)
                LabeledContent("Patterns", value: "\(model.contract.patterns.count)")
                LabeledContent("Looks", value: "\(model.contract.presets.count)")
            }
        }
        .navigationTitle("Settings")
    }
}
