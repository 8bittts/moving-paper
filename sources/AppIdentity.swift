import Foundation

enum AppIdentity {
    static let bundleIdentifier = "com.8bittts.movingpaper"
    static let legacyBundleIdentifiers = [
        "com.8bittts.moving-paper",
    ]
}

enum AppIdentityDefaultsMigration {
    private static let migrationKey = "didMigrateLegacyBundleIdentifierDefaults_v1"

    static func migrateIfNeeded(
        userDefaults: UserDefaults = .standard,
        currentBundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) {
        guard !userDefaults.bool(forKey: migrationKey) else { return }

        let currentBundleIdentifier = currentBundleIdentifier ?? AppIdentity.bundleIdentifier

        for legacyBundleIdentifier in AppIdentity.legacyBundleIdentifiers where legacyBundleIdentifier != currentBundleIdentifier {
            guard let legacyDomain = userDefaults.persistentDomain(forName: legacyBundleIdentifier), !legacyDomain.isEmpty else {
                continue
            }

            let mergedDomain = mergedValues(
                current: userDefaults.persistentDomain(forName: currentBundleIdentifier) ?? [:],
                legacy: legacyDomain
            )

            for (key, value) in mergedDomain where userDefaults.object(forKey: key) == nil {
                userDefaults.set(value, forKey: key)
            }
        }

        userDefaults.set(true, forKey: migrationKey)
    }

    static func mergedValues(current: [String: Any], legacy: [String: Any]) -> [String: Any] {
        var merged = current
        for (key, value) in legacy where merged[key] == nil {
            merged[key] = value
        }
        return merged
    }
}
