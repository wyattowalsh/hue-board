import SwiftUI
import HueBoardKit

struct ScenesView: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""
    @State private var category = "All"
    @State private var favoritesOnly = false
    @State private var favorites = Set(
        UserDefaults.standard.stringArray(forKey: "hue-board.native.favorite-presets.v1") ?? []
    )

    private var categories: [String] {
        ["All"] + Array(Set(model.contract.presets.map(\.category))).sorted()
    }

    private var matchingPresets: [HuePreset] {
        model.contract.presets.filter { preset in
            (category == "All" || preset.category == category)
                && (!favoritesOnly || favorites.contains(preset.id))
                && (search.isEmpty || "\(preset.name) \(preset.description) \(preset.category)"
                    .localizedStandardContains(search))
        }
    }

    var body: some View {
        Group {
            if !model.isReady {
                ConnectPrompt()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        StatusCard()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Find your next look.")
                                .font(.title2.bold())
                            Text("Explore \(model.contract.presets.count) compositions. Loading a look edits only your Studio draft. Play starts Bridge-native dynamic colors.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categories, id: \.self) { option in
                                    if category == option {
                                        Button(option) { category = option }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                    } else {
                                        Button(option) { category = option }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                    }
                                }
                            }
                        }
                        Button {
                            favoritesOnly.toggle()
                        } label: {
                            Label(
                                favoritesOnly ? "Showing favorites" : "Favorites only",
                                systemImage: favoritesOnly ? "star.fill" : "star"
                            )
                        }
                        .buttonStyle(.bordered)
                        .accessibilityAddTraits(favoritesOnly ? [.isSelected] : [])

                        Text("\(matchingPresets.count) matching looks · previews are illustrations")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(matchingPresets) { preset in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.name)
                                            .font(.headline)
                                        Text(preset.category.uppercased())
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button {
                                        toggleFavorite(preset.id)
                                    } label: {
                                        Image(systemName: favorites.contains(preset.id) ? "star.fill" : "star")
                                            .font(.title3)
                                            .frame(width: 36, height: 36)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(
                                        "\(favorites.contains(preset.id) ? "Unfavorite" : "Favorite") \(preset.name)"
                                    )
                                }
                                ScenePreview(
                                    preset: preset,
                                    contract: model.contract,
                                    selected: model.selectedPresetID == preset.id
                                )
                                Text(preset.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 10) {
                                    Button {
                                        model.loadPresetIntoStudio(preset)
                                        model.selectedTab = .live
                                    } label: {
                                        Label("Compose", systemImage: "slider.horizontal.3")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(model.isLiveRunning)
                                    Button {
                                        Task { await model.play(preset) }
                                    } label: {
                                        Label("Play", systemImage: "play.fill")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!model.canPlayScene)
                                }
                            }
                            .padding(16)
                            .background(
                                .quaternary.opacity(0.38),
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                        }

                        if matchingPresets.isEmpty {
                            ContentUnavailableView.search(text: search)
                        }
                        if model.foreignRecoveryPending {
                            Text("A recovery baseline for another Bridge is still pending. Reconnect and restore the original Bridge, or discard that baseline from Settings before playback.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Scenes")
        .searchable(text: $search, prompt: "Search looks, colors or moods")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.isSettingsPresented = true } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private func toggleFavorite(_ id: String) {
        if favorites.contains(id) {
            favorites.remove(id)
        } else {
            favorites.insert(id)
        }
        UserDefaults.standard.set(
            Array(favorites).sorted(),
            forKey: "hue-board.native.favorite-presets.v1"
        )
    }
}
