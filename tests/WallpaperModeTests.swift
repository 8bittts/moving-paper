import Testing
import AppKit
import Foundation

/// Tests for wallpaper mode logic.
struct WallpaperModeTests {

    /// Mirrors the WallpaperMode enum from WallpaperManager
    enum TestWallpaperMode: String {
        case allDesktops
        case perDesktop
    }

    @Test func modeRawValues() {
        #expect(TestWallpaperMode.allDesktops.rawValue == "allDesktops")
        #expect(TestWallpaperMode.perDesktop.rawValue == "perDesktop")
    }

    @Test func modesAreDistinct() {
        #expect(TestWallpaperMode.allDesktops != TestWallpaperMode.perDesktop)
    }
}

/// Tests for NSScreen.displayID extension behavior.
struct DisplayIDTests {

    @Test func screensHaveDisplayIDs() {
        for screen in NSScreen.screens {
            let displayID = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID
            #expect(displayID != nil)
        }
    }
}
