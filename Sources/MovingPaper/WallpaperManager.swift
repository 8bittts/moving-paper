import AppKit
import Combine

/// How wallpapers are assigned to displays.
enum WallpaperMode: String {
    case allDisplays   // one file on every screen
    case perDisplay    // different file per screen
}

/// Central coordinator: manages per-screen wallpaper windows, file selection,
/// playback state, sound, and power-aware pause/resume.
@MainActor
final class WallpaperManager: ObservableObject {

    // MARK: - Published State

    /// Per-display file assignments. Key is CGDirectDisplayID.
    @Published var displayFiles: [CGDirectDisplayID: URL] = [:]

    /// Whether all displays share one wallpaper or each gets its own.
    @Published var mode: WallpaperMode = .allDisplays

    /// User-initiated pause (distinct from system pause).
    @Published var isPaused: Bool = false

    /// Whether video audio is muted.
    @Published var isMuted: Bool = true

    // MARK: - Private State

    private var controllers: [CGDirectDisplayID: WallpaperWindowController] = [:]
    private var screenObserver: Any?
    private var occlusionObservers: [Any] = []
    private var powerObservers: [Any] = []
    private var systemPaused: Bool = false

    init() {
        observeScreenChanges()
        observePowerState()
    }

    // MARK: - Computed Helpers

    /// In allDisplays mode, returns the single shared file URL (if any).
    var sharedFileURL: URL? {
        guard mode == .allDisplays else { return nil }
        return displayFiles.values.first
    }

    /// Human-readable name for a file URL.
    func fileName(for displayID: CGDirectDisplayID) -> String? {
        displayFiles[displayID]?.lastPathComponent
    }

    /// Determine file type from URL extension.
    func fileType(for url: URL) -> WallpaperFileType? {
        switch url.pathExtension.lowercased() {
        case "gif":            return .gif
        case "mov", "mp4", "m4v": return .video
        default:               return nil
        }
    }

    /// All connected display IDs, ordered by screen position (left to right).
    var connectedDisplays: [(id: CGDirectDisplayID, name: String)] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID else { return nil }
            return (id: id, name: screen.localizedName)
        }
    }

    /// Whether any display has a wallpaper assigned.
    var hasAnyWallpaper: Bool {
        !displayFiles.isEmpty
    }

    // MARK: - File Selection

    /// Open file picker and assign result to target display(s).
    /// Pass `nil` for displayID in allDisplays mode.
    func selectFile(for displayID: CGDirectDisplayID? = nil) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .gif, .mpeg4Movie, .quickTimeMovie, .movie,
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a GIF or video file for your Moving Paper wallpaper"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        setWallpaper(url: url, for: displayID)
    }

    /// Assign a wallpaper file to a display (or all displays).
    func setWallpaper(url: URL, for displayID: CGDirectDisplayID? = nil) {
        isPaused = false

        switch mode {
        case .allDisplays:
            // Apply to every connected display
            displayFiles.removeAll()
            for screen in NSScreen.screens {
                if let id = screen.displayID {
                    displayFiles[id] = url
                }
            }
        case .perDisplay:
            if let id = displayID {
                displayFiles[id] = url
            }
        }

        rebuildAllWindows()
    }

    /// Remove wallpaper from a specific display.
    func clearWallpaper(for displayID: CGDirectDisplayID) {
        displayFiles.removeValue(forKey: displayID)
        if let controller = controllers.removeValue(forKey: displayID) {
            controller.close()
        }
    }

    /// Remove all wallpapers.
    func clearAllWallpapers() {
        displayFiles.removeAll()
        tearDownWindows()
    }

    /// Switch between allDisplays and perDisplay modes.
    func setMode(_ newMode: WallpaperMode) {
        guard newMode != mode else { return }

        if newMode == .allDisplays, let firstURL = displayFiles.values.first {
            // Switching to universal: use whatever the first display had
            displayFiles.removeAll()
            for screen in NSScreen.screens {
                if let id = screen.displayID {
                    displayFiles[id] = firstURL
                }
            }
        }
        // Switching to perDisplay: keep existing assignments as-is

        mode = newMode
        rebuildAllWindows()
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            tearDownWindows()
        } else {
            rebuildAllWindows()
        }
    }

    func toggleMute() {
        isMuted.toggle()
        rebuildAllWindows()
    }

    // MARK: - Window Lifecycle

    func rebuildAllWindows() {
        tearDownWindows()
        guard !isPaused else { return }

        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            guard let url = displayFiles[displayID] else { continue }
            guard let type = fileType(for: url) else { continue }

            let controller = WallpaperWindowController(screen: screen)

            switch type {
            case .video:
                controller.show(content: VideoWallpaperView(url: url, isMuted: isMuted))
            case .gif:
                controller.show(content: GIFWallpaperView(url: url))
            }

            controllers[displayID] = controller
            observeOcclusion(for: controller)
        }
    }

    func tearDown() {
        tearDownWindows()
        removeScreenObserver()
        for observer in powerObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        powerObservers.removeAll()
    }

    private func tearDownWindows() {
        for controller in controllers.values {
            controller.close()
        }
        controllers.removeAll()
        occlusionObservers.removeAll()
    }

    // MARK: - Screen Changes

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }

                if self.mode == .allDisplays, let url = self.sharedFileURL {
                    // New displays get the shared wallpaper
                    for screen in NSScreen.screens {
                        if let id = screen.displayID, self.displayFiles[id] == nil {
                            self.displayFiles[id] = url
                        }
                    }
                }

                // Clean up disconnected displays
                let activeIDs = Set(NSScreen.screens.compactMap { $0.displayID })
                for id in self.displayFiles.keys where !activeIDs.contains(id) {
                    self.displayFiles.removeValue(forKey: id)
                }

                self.rebuildAllWindows()
            }
        }
    }

    private func removeScreenObserver() {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
    }

    // MARK: - Power Management

    private func observePowerState() {
        let lowPower = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.evaluatePowerState()
            }
        }
        powerObservers.append(lowPower)

        let thermal = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.evaluatePowerState()
            }
        }
        powerObservers.append(thermal)
    }

    private func evaluatePowerState() {
        let shouldPause =
            ProcessInfo.processInfo.isLowPowerModeEnabled
            || ProcessInfo.processInfo.thermalState == .serious
            || ProcessInfo.processInfo.thermalState == .critical

        if shouldPause && !systemPaused {
            systemPaused = true
            tearDownWindows()
        } else if !shouldPause && systemPaused {
            systemPaused = false
            if !isPaused {
                rebuildAllWindows()
            }
        }
    }

    private func observeOcclusion(for controller: WallpaperWindowController) {
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: controller.panel,
            queue: .main
        ) { _ in
            // Desktop-level windows are automatically deprioritized by the
            // compositor when fully occluded. No manual pause needed.
        }
        occlusionObservers.append(observer)
    }
}

// MARK: - Helpers

enum WallpaperFileType {
    case gif
    case video
}

extension NSScreen {
    /// Stable display ID for this screen.
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
