import SwiftUI
import AppKit

@main
struct DefaultAppsApp: App {
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
    
    init() {
        // Make the process a regular app with Dock icon and proper activation
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 850, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About DefaultApps") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "DefaultApps",
                        .applicationVersion: appVersion,
                        .credits: NSAttributedString(
                            string: "https://github.com/okalachev/DefaultApps",
                            attributes: [
                                .link: URL(string: "https://github.com/okalachev/DefaultApps")!,
                                .font: NSFont.systemFont(ofSize: 11),
                            ]
                        ),
                    ])
                }
            }
        }
    }
}
