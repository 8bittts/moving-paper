import Foundation
import Testing
@testable import MovingPaper

struct AppIdentityDefaultsMigrationTests {
    @Test
    func mergesLegacyDefaultsWithoutOverwritingCurrentValues() {
        let current = [
            "wallpaperMode": "allDesktops",
            "isMuted": false,
        ] as [String: Any]
        let legacy = [
            "wallpaperMode": "perDesktop",
            "desktopFiles": [["path": "/tmp/example.mp4"]],
        ] as [String: Any]

        let merged = AppIdentityDefaultsMigration.mergedValues(current: current, legacy: legacy)

        #expect((merged["wallpaperMode"] as? String) == "allDesktops")
        #expect((merged["isMuted"] as? Bool) == false)
        #expect((merged["desktopFiles"] as? [[String: String]])?.first?["path"] == "/tmp/example.mp4")
    }

    @Test
    func migratesLegacyBundleIdentifierDomainIntoCurrentDomain() {
        let currentSuite = "test.current.\(UUID().uuidString)"
        let legacySuite = "com.8bittts.moving-paper"
        let currentDefaults = UserDefaults(suiteName: currentSuite)!

        currentDefaults.removePersistentDomain(forName: currentSuite)
        currentDefaults.removePersistentDomain(forName: legacySuite)

        currentDefaults.setPersistentDomain([
            "wallpaperMode": "perDesktop",
            "desktopFiles": [["path": "/tmp/example.mp4"]],
            "isMuted": true,
        ], forName: legacySuite)

        AppIdentityDefaultsMigration.migrateIfNeeded(
            userDefaults: currentDefaults,
            currentBundleIdentifier: currentSuite
        )

        #expect(currentDefaults.string(forKey: "wallpaperMode") == "perDesktop")
        #expect((currentDefaults.array(forKey: "desktopFiles") as? [[String: String]])?.first?["path"] == "/tmp/example.mp4")
        #expect(currentDefaults.object(forKey: "isMuted") as? Bool == true)
    }
}
