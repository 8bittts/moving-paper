import Combine
@preconcurrency import Sparkle

/// Sparkle auto-updater wrapper for MovingPaper.
/// Checks for updates via an appcast feed and handles EdDSA-signed releases.
@MainActor
final class MovingPaperUpdater: NSObject, ObservableObject {

    enum UpdateStatus: Equatable {
        case idle
        case checking
        case available(version: String)
        case upToDate
        case error(message: String)
    }

    @Published private(set) var status: UpdateStatus = .idle
    @Published private(set) var canCheckForUpdates = false

    private let userDriver: MovingPaperUpdateDriver
    private var updater: SPUUpdater?
    private var cancellables = Set<AnyCancellable>()
    private var started = false

    override init() {
        self.userDriver = MovingPaperUpdateDriver()
        super.init()

        // Sparkle requires a valid app bundle with SUFeedURL + SUPublicEDKey.
        // In dev (swift run), these are missing — updater stays dormant.
        guard Self.hostHasSparkleConfig() else { return }

        userDriver.onStatusEvent = { [weak self] event in
            self?.handle(event)
        }

        let updater = SPUUpdater(
            hostBundle: Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: userDriver,
            delegate: userDriver
        )
        self.updater = updater

        updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
            .store(in: &cancellables)
    }

    /// Start the updater (call once after app launch).
    func start() {
        guard !started else { return }
        started = true
        guard let updater else { return }

        do {
            try updater.start()
        } catch {
            status = .error(message: "Updater failed to start: \(error.localizedDescription)")
        }
    }

    /// Trigger a manual update check (user-initiated).
    func checkForUpdates() {
        guard let updater else {
            status = .error(message: "Updates unavailable in development builds.")
            return
        }

        status = .checking
        updater.checkForUpdates()
    }

    // MARK: - Host Validation

    nonisolated private static func hostHasSparkleConfig() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier,
              !bundleID.isEmpty else { return false }
        guard let buildVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String,
              !buildVersion.isEmpty else { return false }
        guard let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !shortVersion.isEmpty else { return false }
        guard let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              !feedURL.isEmpty else { return false }
        guard let pubKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              !pubKey.isEmpty else { return false }
        return true
    }

    private func handle(_ event: MovingPaperUpdateStatusEvent) {
        switch event {
        case .available(let version):
            status = .available(version: version)
        case .upToDate:
            status = .upToDate
        case .aborted(let message):
            guard case .checking = status else { return }
            status = .error(message: message)
        }
    }
}
