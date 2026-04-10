import CoreGraphics
import Foundation
import Testing
@testable import MovingPaper

struct AllDesktopAssignmentReconcilerTests {

    @Test func addsMissingConnectedDisplaysUsingTheSharedValue() {
        let existing: [DesktopKey: URL] = [
            DesktopKey(displayID: 1): URL(filePath: "/tmp/wallpaper.mp4"),
        ]

        let reconciled = AllDesktopAssignmentReconciler.reconcile(
            existing: existing,
            connectedDisplayIDs: [1, 2],
            sharedValue: URL(filePath: "/tmp/wallpaper.mp4")
        )

        #expect(reconciled.didChange)
        #expect(reconciled.assignments[DesktopKey(displayID: 1)] == URL(filePath: "/tmp/wallpaper.mp4"))
        #expect(reconciled.assignments[DesktopKey(displayID: 2)] == URL(filePath: "/tmp/wallpaper.mp4"))
    }

    @Test func removesDisconnectedDisplays() {
        let existing: [DesktopKey: String] = [
            DesktopKey(displayID: 1): "shared-youtube-url",
            DesktopKey(displayID: 2): "shared-youtube-url",
        ]

        let reconciled = AllDesktopAssignmentReconciler.reconcile(
            existing: existing,
            connectedDisplayIDs: [1],
            sharedValue: "shared-youtube-url"
        )

        #expect(reconciled.didChange)
        #expect(reconciled.assignments[DesktopKey(displayID: 1)] == "shared-youtube-url")
        #expect(reconciled.assignments[DesktopKey(displayID: 2)] == nil)
    }
}
