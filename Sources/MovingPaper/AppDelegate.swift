import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private var wallpaperManager: WallpaperManager?
    private var updater: MovingPaperUpdater?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only — no Dock icon, no Cmd+Tab entry
        NSApp.setActivationPolicy(.accessory)

        let manager = WallpaperManager()
        self.wallpaperManager = manager

        let sparkleUpdater = MovingPaperUpdater()
        self.updater = sparkleUpdater

        self.statusBar = StatusBarController(
            wallpaperManager: manager,
            updater: sparkleUpdater
        )

        sparkleUpdater.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        wallpaperManager?.tearDown()
    }
}
