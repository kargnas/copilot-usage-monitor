import SwiftUI

@main
struct CopilotMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .windowResizability(.contentSize)
    }
}
