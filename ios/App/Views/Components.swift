import SwiftUI
import HueBoardKit

struct PlaybackBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.hasRestorePoint || model.isBusy || model.playbackSnapshot.mode != .idle {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(model.playbackSnapshot.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                if model.hasRestorePoint {
                    Button("Stop & restore") {
                        Task { await model.stopAndRestore() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isBusy)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Divider() }
        }
    }

    private var statusTitle: String {
        switch model.playbackSnapshot.mode {
        case .bridge: "Bridge playback"
        case .liveForeground: "Native Live · foreground"
        case .liveContinued: "Native Live · continued"
        case .stopping: "Restoring"
        case .failed: "Needs attention"
        case .idle: model.hasRestorePoint ? "Restore point available" : "Ready"
        }
    }

    private var statusIcon: String {
        switch model.playbackSnapshot.mode {
        case .bridge: "antenna.radiowaves.left.and.right"
        case .liveForeground, .liveContinued: "waveform.path.ecg"
        case .stopping: "arrow.uturn.backward.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .idle: "lightbulb.fill"
        }
    }

    private var statusColor: Color {
        switch model.playbackSnapshot.phase {
        case .uncertain, .failed: .orange
        case .accepted, .reported, .running: .accentColor
        default: .secondary
        }
    }
}

struct SceneSwatch: View {
    let preset: HuePreset
    let contract: HueBoardContract

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .accessibilityHidden(true)
    }

    private var colors: [Color] {
        let values = contract.palette(index: preset.palette)?.colors
            ?? ["#102CBA", "#00B9F2", "#36E5D1", "#A4ED51"]
        return values.map { Color(hex: $0) }
    }
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        let value = UInt64(clean, radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
