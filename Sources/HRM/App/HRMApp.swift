import SwiftUI

@main
struct HRMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanelView(appState: appState)
        } label: {
            Image(systemName: appState.isEnabled ? "keyboard.fill" : "keyboard")
        }
        .menuBarExtraStyle(.window)
    }
}
