import SwiftUI

@main
struct HueBoardApp: App {
    @State private var model = AppModel()

    init() {
        ContinuedLiveCoordinator.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
