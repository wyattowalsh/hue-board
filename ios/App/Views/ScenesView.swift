import HueBoardKit
import SwiftUI

struct ScenesView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var searchFocused: Bool
    @State private var search = ""
    @State private var category: String?
    @State private var favoritesOnly = false

    private var matches: [HuePreset] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.contract.presets.filter { scene in
            (category == nil || scene.category == category)
                && (!favoritesOnly || model.favoritePresetIDs.contains(scene.id))
                && (query.isEmpty || "\(scene.name) \(scene.description) \(scene.category)"
                    .localizedStandardContains(query))
        }
    }

    private var filterDescription: String {
        [favoritesOnly ? "Favorites" : nil, category].compactMap { $0 }.joined(separator: ", ")
    }

    var body: some View {
        let scenes = matches
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("Search scenes", text: $search)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { searchFocused = false }
                        .accessibilityIdentifier("scene-search")
                    if !search.isEmpty {
                        Button("Clear search", systemImage: "xmark.circle.fill") { search = "" }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("scene-search-clear")
                    }
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                filterMenu
            }
            .padding(.horizontal)
            Text([scenes.count == 1 ? "1 scene" : "\(scenes.count) scenes", filterDescription]
                .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .accessibilityIdentifier("scene-match-count")
            if scenes.isEmpty {
                ContentUnavailableView {
                    Label("No scenes found", systemImage: "magnifyingglass")
                } description: {
                    Text(favoritesOnly && model.favoritePresetIDs.isEmpty
                        ? "Mark a scene as a favorite to find it here." : "Try another search or filter.")
                } actions: {
                    Button("Show all scenes") {
                        search = ""
                        category = nil
                        favoritesOnly = false
                        searchFocused = false
                    }
                }
            } else {
                List(scenes) { scene in
                    NavigationLink {
                        SceneDetailView(preset: scene)
                    } label: {
                        HStack(spacing: 14) {
                            ScenePreview(preset: scene, contract: model.contract, compact: true)
                                .frame(width: 62, height: 48)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(scene.name).font(.headline)
                                Text(scene.category).font(.subheadline).foregroundStyle(.secondary)
                            }
                            if model.favoritePresetIDs.contains(scene.id) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Favorite")
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .accessibilityIdentifier("scene-\(scene.id)")
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationTitle("Scenes")
        .onDisappear { searchFocused = false }
    }

    private var filterMenu: some View {
        Menu {
            Toggle("Favorites only", isOn: $favoritesOnly)
            Picker("Category", selection: $category) {
                Text("All categories").tag(String?.none)
                ForEach(Set(model.contract.presets.map(\.category)).sorted(), id: \.self) { name in
                    Text(name).tag(Optional(name))
                }
            }
        } label: {
            Image(systemName: filterDescription.isEmpty
                ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .font(.title2)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Filter scenes")
        .accessibilityValue(filterDescription.isEmpty ? "All scenes" : filterDescription)
    }
}

private struct SceneDetailView: View {
    @Environment(AppModel.self) private var model
    let preset: HuePreset

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    ScenePreview(preset: preset, contract: model.contract)
                    Text(preset.description)
                }
                .padding(.vertical, 6)
            } header: {
                Text(preset.category)
            }
            Section {
                Button("Edit in Studio", systemImage: "slider.horizontal.3") {
                    model.loadPresetIntoStudio(preset)
                    model.studioPath = [.mix]
                    model.selectedTab = .live
                }
                .disabled(model.isLiveRunning)
                .accessibilityIdentifier("compose-\(preset.id)")
                if model.isReady {
                    Button("Play on lights", systemImage: "play.fill") {
                        Task { await model.play(preset) }
                    }
                    .disabled(!model.canPlayScene || model.selectedArea == nil)
                    .accessibilityIdentifier("play-\(preset.id)")
                } else {
                    Button("Connect Bridge to play", systemImage: "link") { model.presentConnection() }
                }
            } footer: {
                if let area = model.selectedArea, model.isReady {
                    Text("Plays in \(area.name). The Bridge keeps playing when you leave the app.")
                }
            }
        }
        .navigationTitle(preset.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let favorite = model.favoritePresetIDs.contains(preset.id)
                Button(favorite ? "Remove from favorites" : "Add to favorites",
                       systemImage: favorite ? "star.fill" : "star") {
                    model.toggleFavoritePreset(preset.id)
                }
                .labelStyle(.iconOnly)
            }
        }
    }
}
