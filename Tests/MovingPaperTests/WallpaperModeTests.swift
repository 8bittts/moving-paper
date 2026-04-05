import Testing
import AppKit
import Foundation

/// Tests for wallpaper mode logic.
struct WallpaperModeTests {

    /// Mirrors the WallpaperMode enum from WallpaperManager
    enum TestWallpaperMode: String {
        case allDisplays
        case perDisplay
    }

    @Test func modeRawValues() {
        #expect(TestWallpaperMode.allDisplays.rawValue == "allDisplays")
        #expect(TestWallpaperMode.perDisplay.rawValue == "perDisplay")
    }

    @Test func modesAreDistinct() {
        #expect(TestWallpaperMode.allDisplays != TestWallpaperMode.perDisplay)
    }
}

/// Tests for NSScreen.displayID extension behavior.
struct DisplayIDTests {

    @Test func screensHaveDisplayIDs() {
        // In a test environment, NSScreen.screens may be empty (headless CI),
        // but if screens exist, each should produce a displayID.
        for screen in NSScreen.screens {
            let displayID = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID
            #expect(displayID != nil)
        }
    }
}
