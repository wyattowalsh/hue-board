import SwiftUI
import HueBoardKit

struct ConnectionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDestructiveReset = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Find a Hue Bridge") {
                    Button {
                        Task { await model.discoverBridges() }
                    } label: {
                        Label("Discover Hue Bridges", systemImage: "magnifyingglass")
                    }
                    .disabled(model.isBusy)

                    ForEach(model.discoveredBridges) { candidate in
                        Button {
                            Task { await model.probe(candidate) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.host)
                                Text(candidate.id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(model.isBusy)
                    }
                }

                Section("Manual address") {
                    TextField("192.168.1.10 or hue-bridge.local", text: $model.manualHost)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await model.probeManualHost() }
                    } label: {
                        Label("Verify Bridge", systemImage: "checkmark.shield")
                    }
                    .disabled(model.manualHost.isEmpty || model.isBusy)
                }

                if let pending = model.pendingProfile {
                    Section("Verified Bridge") {
                        LabeledContent("Bridge", value: pending.bridgeID)
                        LabeledContent("Address", value: pending.displayHost)
                        if let fingerprint = pending.displayCertificateSHA256 {
                            LabeledContent("Certificate") {
                                Text(fingerprint)
                                    .font(.caption2.monospaced())
                                    .multilineTextAlignment(.trailing)
                                    .textSelection(.enabled)
                            }
                        }
                        Text(
                            "Hue Board verified that the local API identity matches the TLS certificate. The certificate fingerprint is pinned after pairing; later changes fail closed. Verify first contact on a trusted home network."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        Text(
                            "Press the physical center button on the Bridge, then pair. Hue Board stores the application key in Keychain."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        Button {
                            Task { await model.pairPendingBridge() }
                        } label: {
                            Label("Pair now", systemImage: "link.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isBusy)
                    }
                }

                if model.profile != nil, !model.isReady {
                    Section("Saved connection") {
                        Text(
                            "If a Bridge replacement or firmware certificate change cannot be verified, remove the saved credential and pair again only after checking the physical Bridge."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            Task { await model.forgetBridge() }
                        } label: {
                            Label("Forget saved Bridge", systemImage: "trash")
                        }
                        .disabled(!model.canForgetBridge)

                        if model.hasRestorePoint {
                            Button(role: .destructive) {
                                confirmsDestructiveReset = true
                            } label: {
                                Label("Discard recovery & forget", systemImage: "trash.slash")
                            }
                            .disabled(model.isBusy)
                            Text(
                                "This last-resort reset deletes the only saved pre-playback state. Use it only when the original Bridge cannot be recovered."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text(
                        "Opening, verifying, pairing, and refreshing never change a light. Local requests require a private-LAN host, reject redirects, match the certificate Bridge ID to the API identity, and pin the leaf certificate SHA-256 after verification."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Connect Bridge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .disabled(!model.isReady && model.manualHost.isEmpty)
                }
            }
            .overlay {
                if model.isBusy {
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .confirmationDialog(
                "Delete the restore baseline?",
                isPresented: $confirmsDestructiveReset,
                titleVisibility: .visible
            ) {
                Button("Discard recovery & forget Bridge", role: .destructive) {
                    Task { await model.discardRecoveryAndForgetBridge() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This permanently deletes the application key, certificate pin, scene registry, and the only saved state needed to restore lights changed by the active playback session."
                )
            }
        }
    }
}
