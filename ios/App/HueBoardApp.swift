import SwiftUI

@main
struct HueBoardApp: App {
    @State private var model = AppModel()

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["HUE_BOARD_WRITE_AUDIT"] == "1" {
            print("HUE_BOARD_WRITE_AUDIT_ACTIVE")
        }
        #endif
        ContinuedLiveCoordinator.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
