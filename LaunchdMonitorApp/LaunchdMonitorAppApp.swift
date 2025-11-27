import SwiftUI

@main
struct LaunchdMonitorApp: App {
    // Create the shared controller
    @StateObject private var controller = MonitorController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
                .frame(width: 90, height: 400) // initial compact width to show icons
                .onAppear {
                    controller.setupFloatingWindow() // set window level & position
                    controller.startAutoRefresh()
                }
                .onDisappear {
                    controller.stopAutoRefresh()
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
