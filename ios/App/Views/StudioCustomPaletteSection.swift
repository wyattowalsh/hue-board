import SwiftUI
import UIKit
import HueBoardKit

struct StudioCustomPaletteSection: View {
    @Environment(AppModel.self) private var model

    private let names = ["Base", "Motion", "Secondary", "Accent"]

    private var customPaletteIndex: Int? {
        model.contract.palettes.first(where: { $0.name == "Custom four-color" })?.index
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Create your own palette", systemImage: "paintpalette.fill")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("Choose four colors, then use them in either side of your Studio mix.")
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
                              [r, g, b].allSatisfy(\.isFinite),
                              model.studioSettings.customColors.count == 4 else {
                            model.errorMessage = "The custom color could not be converted to sRGB."
                            return
                        }
                        let channels = [r, g, b].map { Int((min(max($0, 0), 1) * 255).rounded()) }
                        let hex = String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
                        var updated = model.studioSettings
                        updated.customColors[index] = hex
                        model.studioSettings = updated
                    }
                ), supportsOpacity: false)
            }

            if let customPaletteIndex {
                let inA = model.studioSettings.paletteA == customPaletteIndex
                let inB = model.studioSettings.paletteB == customPaletteIndex
                ViewThatFits(in: .horizontal) {
                    HStack {
                        usePaletteButton(side: "A", assigned: inA, index: customPaletteIndex, keyPath: \.paletteA)
                        usePaletteButton(side: "B", assigned: inB, index: customPaletteIndex, keyPath: \.paletteB)
                    }
                    VStack(alignment: .leading) {
                        usePaletteButton(side: "A", assigned: inA, index: customPaletteIndex, keyPath: \.paletteA)
                        usePaletteButton(side: "B", assigned: inB, index: customPaletteIndex, keyPath: \.paletteB)
                    }
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        .disabled(model.isLiveRunning)
    }

    private func usePaletteButton(
        side: String,
        assigned: Bool,
        index: Int,
        keyPath: WritableKeyPath<HueEngineSettings, Int>
    ) -> some View {
        Button(assigned ? "Using in \(side)" : "Use in \(side)", systemImage: assigned ? "checkmark" : "plus") {
            model.studioSettings[keyPath: keyPath] = index
        }
        .buttonStyle(.bordered)
        .disabled(assigned)
        .accessibilityIdentifier("studio-custom-palette-\(side)")
    }
}
