import SwiftUI
import HueBoardKit

struct ScenesView: View {
    @Environment(AppModel.self) private var model
    @State private var category = "All"

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18, pinnedViews: .sectionHeaders) {
                if !model.isReady {
                    ContentUnavailableView {
                        Label("Preview mode", systemImage: "network.slash")
                    } description: {
                        Text("Browse every look now. Connect a Bridge to enable Play.")
                    } actions: {
                        Button("Connect") { model.isConnectionSheetPresented = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                }

                Section {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filteredPresets) { preset in
                            SceneCard(preset: preset)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                } header: {
                    categoryPicker
                        .padding(.vertical, 10)
                        .background(.background)
                }
            }
        }
        .navigationTitle("Scenes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.selectedTab = .live
                } label: {
                    Label("Native Live", systemImage: "waveform.path")
                }
            }
        }
    }

    private var categories: [String] {
        ["All"] + Array(Set(model.contract.presets.map(\.category))).sorted()
    }

    private var filteredPresets: [HuePreset] {
        category == "All" ? model.contract.presets : model.contract.presets.filter { $0.category == category }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { value in
                    Button(value) { category = value }
                        .buttonStyle(.bordered)
                        .tint(category == value ? Color.accentColor : Color.secondary)
                        .accessibilityAddTraits(category == value ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct SceneCard: View {
    @Environment(AppModel.self) private var model
    let preset: HuePreset

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                SceneSwatch(preset: preset, contract: model.contract)
                    .frame(height: 142)
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.category.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.76))
                    Text(preset.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(14)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(preset.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Button {
                    Task { await model.play(preset) }
                } label: {
                    Label("Play on Bridge", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canPlayScene)
            }
            .padding(14)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}
