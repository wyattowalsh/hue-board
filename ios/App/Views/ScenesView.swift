import SwiftUI
import HueBoardKit

struct ScenesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var searchFocused: Bool
    @State private var search = ""
    @State private var category = "All"
    @State private var favoritesOnly = false

    private var categories: [String] {
        ["All"] + Array(Set(model.contract.presets.map(\.category))).sorted()
    }

    private var query: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingPresets: [HuePreset] {
        model.contract.presets.filter { preset in
            (category == "All" || preset.category == category)
                && (!favoritesOnly || model.favoritePresetIDs.contains(preset.id))
                && (query.isEmpty || "\(preset.name) \(preset.description) \(preset.category)"
                    .localizedStandardContains(query))
        }
    }

    var body: some View {
        let matches = matchingPresets
        VStack(spacing: 0) {
            searchBar(matchCount: matches.count)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if !searchFocused && query.isEmpty {
                        introduction
                    }
                    filters
                    if matches.isEmpty {
                        emptyState
                    }
                    ForEach(matches) { preset in
                        lookCard(preset)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Scenes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.isSettingsPresented = true } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
            }
        }
        .onDisappear { searchFocused = false }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find your next look.")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Compose opens a look in your Studio draft. Play starts Bridge-native colors.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if model.foreignRecoveryPending {
                Text("A recovery baseline for another Bridge is pending. Reconnect the original Bridge to restore it, or discard that baseline from Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if !model.isReady {
                Button("Connect Bridge to play looks", systemImage: "dot.radiowaves.left.and.right") {
                    searchFocused = false
                    model.presentConnection()
                }
                .font(.subheadline)
            }
        }
    }

    private func searchBar(matchCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search looks, colors or moods", text: $search)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { searchFocused = false }
                    .accessibilityIdentifier("scene-search")
                if !search.isEmpty {
                    Button {
                        search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .accessibilityIdentifier("scene-search-clear")
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, search.isEmpty ? 12 : 0)
            .frame(minHeight: 44)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            Text(matchCount == 1 ? "1 matching look" : "\(matchCount) matching looks")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("scene-match-count")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    favoritesOnly.toggle()
                } label: {
                    Label("Favorites", systemImage: favoritesOnly ? "star.fill" : "star")
                }
                .buttonStyle(.bordered)
                .accessibilityAddTraits(favoritesOnly ? [.isSelected] : [])

                ForEach(categories, id: \.self) { option in
                    if category == option {
                        Button(option) { category = option }
                            .buttonStyle(.borderedProminent)
                            .accessibilityAddTraits(.isSelected)
                    } else {
                        Button(option) { category = option }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No matching looks", systemImage: "magnifyingglass")
        } description: {
            Text(favoritesOnly && model.favoritePresetIDs.isEmpty
                 ? "Star a look to add it to your favorites."
                 : "Try another search or clear the filters.")
        } actions: {
            Button("Show all looks") {
                search = ""
                category = "All"
                favoritesOnly = false
                searchFocused = false
            }
        }
    }

    private func lookCard(_ preset: HuePreset) -> some View {
        let isFavorite = model.favoritePresetIDs.contains(preset.id)
        let actionLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(preset.category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.toggleFavoritePreset(preset.id)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(isFavorite ? "Unfavorite" : "Favorite") \(preset.name)")
            }
            ScenePreview(preset: preset, contract: model.contract, selected: model.selectedPresetID == preset.id)
            Text(preset.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            actionLayout {
                Button {
                    searchFocused = false
                    model.loadPresetIntoStudio(preset)
                    model.selectedTab = .live
                } label: {
                    Label("Compose", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.isLiveRunning)
                .accessibilityIdentifier("compose-\(preset.id)")
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
        .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 20))
    }
}
