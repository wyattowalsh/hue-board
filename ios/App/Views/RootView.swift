import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            NavigationStack { LightsView() }
                .tabItem { Label("Lights", systemImage: "lightbulb.2.fill") }
                .tag(AppModel.Tab.lights)

            NavigationStack { ScenesView() }
                .tabItem { Label("Scenes", systemImage: "sparkles.rectangle.stack") }
                .tag(AppModel.Tab.scenes)

            NavigationStack { LiveView() }
                .tabItem { Label("Live", systemImage: "waveform.path") }
                .tag(AppModel.Tab.live)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppModel.Tab.settings)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlaybackBanner()
        }
        .sheet(isPresented: $model.isConnectionSheetPresented) {
            ConnectionSheet()
                .environment(model)
        }
        .alert("Hue Board", isPresented: errorPresented) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
        .task { await model.bootstrap() }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}
