import SwiftUI
import UIKit
import HueBoardKit

struct StudioCustomPaletteSection: View {
    @Environment(AppModel.self) private var model

    private let names = ["Base", "Motion", "Secondary", "Accent"]

    private var selectedCustomPalette: Bool {
        guard let custom = model.contract.palettes.first(where: {
            $0.name == "Custom four-color"
        }) else { return false }
        return model.studioSettings.paletteA == custom.index
            || model.studioSettings.paletteB == custom.index
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Create your own palette", systemImage: "paintpalette.fill")
                .font(.headline)
            Text("Four colors for the actual shared pattern engine. Choose Custom four-color in Palette A or B to use them.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(0..<names.count, id: \.self) { index in
                ColorPicker(names[index], selection: Binding(
                    get: {
                        guard index < model.studioSettings.customColors.count,
                              let rgb = try? RGB(hex: model.studioSettings.customColors[index])
                        else { return Color.gray }
                        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
                    },
                    set: { color in
                        let uiColor = UIColor(color)
                        var r: CGFloat = 0
                        var g: CGFloat = 0
                        var b: CGFloat = 0
                        var a: CGFloat = 0
                        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a),
                              model.studioSettings.customColors.count == 4 else {
                            model.errorMessage = "The custom color could not be converted to sRGB."
                            return
                        }
                        let hex = String(
                            format: "#%02X%02X%02X",
                            Int((r * 255).rounded()),
                            Int((g * 255).rounded()),
                            Int((b * 255).rounded())
                        )
                        var updated = model.studioSettings
                        updated.customColors[index] = hex
                        model.studioSettings = updated
                    }
                ), supportsOpacity: false)
            }

            if !selectedCustomPalette {
                Text("Select Custom four-color in an A/B palette to preview these colors in the live engine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Custom palette is active in the Studio preview", systemImage: "checkmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        .disabled(model.isLiveRunning)
    }
}
