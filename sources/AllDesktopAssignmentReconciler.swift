import CoreGraphics
import Foundation

enum AllDesktopAssignmentReconciler {
    static func reconcile<Value: Equatable>(
        existing: [DesktopKey: Value],
        connectedDisplayIDs: [CGDirectDisplayID],
        sharedValue: Value?
    ) -> (assignments: [DesktopKey: Value], didChange: Bool) {
        guard let sharedValue else {
            return (existing, false)
        }

        let expectedKeys = Set(connectedDisplayIDs.map(DesktopKey.init(displayID:)))
        var assignments = existing
        var didChange = false

        for key in Array(assignments.keys) where !expectedKeys.contains(key) {
            assignments.removeValue(forKey: key)
            didChange = true
        }

        for displayID in connectedDisplayIDs {
            let key = DesktopKey(displayID: displayID)
            if assignments[key] != sharedValue {
                assignments[key] = sharedValue
                didChange = true
            }
        }

        return (assignments, didChange)
    }
}
