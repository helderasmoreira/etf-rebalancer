import AppKit
import SwiftUI

@main
struct ETFRebalancerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("ETF Rebalancer", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 980, minHeight: 560)
        }
        .defaultSize(width: 1240, height: 680)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh Prices") {
                    Task { await model.refreshPrices() }
                }
                .keyboardShortcut("r")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
