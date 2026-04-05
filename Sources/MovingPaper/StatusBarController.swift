import AppKit
import Combine

/// Menu bar status item with wallpaper controls.
/// Adapts menu structure based on wallpaper mode (all displays vs per display).
@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem?
    private let wallpaperManager: WallpaperManager
    private let updater: MovingPaperUpdater
    private var cancellables = Set<AnyCancellable>()

    init(wallpaperManager: WallpaperManager, updater: MovingPaperUpdater) {
        self.wallpaperManager = wallpaperManager
        self.updater = updater

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let icon = MenuBarIcon.brandIcon()
            icon.accessibilityDescription = "Moving Paper"
            button.image = icon
        }
        self.statusItem = item

        rebuildMenu()

        // Rebuild menu when any relevant state changes
        wallpaperManager.$displayFiles
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        wallpaperManager.$isPaused
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        wallpaperManager.$isMuted
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        wallpaperManager.$mode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        updater.$canCheckForUpdates
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        switch wallpaperManager.mode {
        case .allDisplays:
            buildAllDisplaysMenu(menu)
        case .perDisplay:
            buildPerDisplayMenu(menu)
        }

        menu.addItem(.separator())

        // ── Sound toggle ──
        let soundTitle = wallpaperManager.isMuted ? "Sound: Off" : "Sound: On"
        let soundItem = NSMenuItem(
            title: soundTitle,
            action: #selector(toggleMute),
            keyEquivalent: "s"
        )
        soundItem.target = self
        if !wallpaperManager.isMuted {
            soundItem.state = .on
        }
        menu.addItem(soundItem)

        // ── Mode toggle ──
        let modeMenu = NSMenu()

        let allItem = NSMenuItem(
            title: "All Displays",
            action: #selector(setModeAllDisplays),
            keyEquivalent: ""
        )
        allItem.target = self
        allItem.state = wallpaperManager.mode == .allDisplays ? .on : .off
        modeMenu.addItem(allItem)

        let perItem = NSMenuItem(
            title: "Per Display",
            action: #selector(setModePerDisplay),
            keyEquivalent: ""
        )
        perItem.target = self
        perItem.state = wallpaperManager.mode == .perDisplay ? .on : .off
        modeMenu.addItem(perItem)

        let modeItem = NSMenuItem(title: "Wallpaper Mode", action: nil, keyEquivalent: "")
        modeItem.submenu = modeMenu
        menu.addItem(modeItem)

        menu.addItem(.separator())

        // ── Pause / Resume ──
        if wallpaperManager.hasAnyWallpaper {
            let pauseTitle = wallpaperManager.isPaused ? "Resume" : "Pause"
            let pauseKey = wallpaperManager.isPaused ? "r" : "p"
            let pauseItem = NSMenuItem(
                title: pauseTitle,
                action: #selector(togglePause),
                keyEquivalent: pauseKey
            )
            pauseItem.target = self
            menu.addItem(pauseItem)

            menu.addItem(.separator())
        }

        // ── Check for Updates ──
        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: "u"
        )
        updateItem.target = self
        updateItem.isEnabled = updater.canCheckForUpdates
        menu.addItem(updateItem)

        menu.addItem(.separator())

        // ── Quit ──
        let quitItem = NSMenuItem(
            title: "Quit Moving Paper",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - All Displays Mode Menu

    private func buildAllDisplaysMenu(_ menu: NSMenu) {
        if let url = wallpaperManager.sharedFileURL {
            let fileItem = NSMenuItem(title: url.lastPathComponent, action: nil, keyEquivalent: "")
            fileItem.isEnabled = false
            menu.addItem(fileItem)
            menu.addItem(.separator())

            let removeItem = NSMenuItem(
                title: "Remove Wallpaper",
                action: #selector(clearAllWallpapers),
                keyEquivalent: ""
            )
            removeItem.target = self
            menu.addItem(removeItem)

            menu.addItem(.separator())
        }

        let chooseItem = NSMenuItem(
            title: "Choose File...",
            action: #selector(chooseFileForAll),
            keyEquivalent: "o"
        )
        chooseItem.target = self
        menu.addItem(chooseItem)
    }

    // MARK: - Per Display Mode Menu

    private func buildPerDisplayMenu(_ menu: NSMenu) {
        let displays = wallpaperManager.connectedDisplays

        if displays.isEmpty {
            let noDisplays = NSMenuItem(title: "No Displays", action: nil, keyEquivalent: "")
            noDisplays.isEnabled = false
            menu.addItem(noDisplays)
            return
        }

        for (index, display) in displays.enumerated() {
            let displayMenu = NSMenu()

            if let fileName = wallpaperManager.fileName(for: display.id) {
                let fileItem = NSMenuItem(title: fileName, action: nil, keyEquivalent: "")
                fileItem.isEnabled = false
                displayMenu.addItem(fileItem)
                displayMenu.addItem(.separator())

                let removeItem = NSMenuItem(
                    title: "Remove",
                    action: #selector(clearDisplayWallpaper(_:)),
                    keyEquivalent: ""
                )
                removeItem.target = self
                removeItem.tag = Int(display.id)
                displayMenu.addItem(removeItem)

                displayMenu.addItem(.separator())
            }

            let chooseItem = NSMenuItem(
                title: "Choose File...",
                action: #selector(chooseFileForDisplay(_:)),
                keyEquivalent: ""
            )
            chooseItem.target = self
            chooseItem.tag = Int(display.id)
            displayMenu.addItem(chooseItem)

            let hasFile = wallpaperManager.displayFiles[display.id] != nil
            let indicator = hasFile ? ">" : " "
            let displayTitle = "\(display.name) \(indicator)"
            let displayItem = NSMenuItem(title: displayTitle, action: nil, keyEquivalent: "")
            displayItem.submenu = displayMenu

            if index < 9 {
                displayItem.keyEquivalent = "\(index + 1)"
            }

            menu.addItem(displayItem)
        }

        if wallpaperManager.hasAnyWallpaper {
            menu.addItem(.separator())
            let clearAllItem = NSMenuItem(
                title: "Remove All Wallpapers",
                action: #selector(clearAllWallpapers),
                keyEquivalent: ""
            )
            clearAllItem.target = self
            menu.addItem(clearAllItem)
        }
    }

    // MARK: - Actions

    @objc private func chooseFileForAll() {
        wallpaperManager.selectFile()
    }

    @objc private func chooseFileForDisplay(_ sender: NSMenuItem) {
        let displayID = CGDirectDisplayID(sender.tag)
        wallpaperManager.selectFile(for: displayID)
    }

    @objc private func clearDisplayWallpaper(_ sender: NSMenuItem) {
        let displayID = CGDirectDisplayID(sender.tag)
        wallpaperManager.clearWallpaper(for: displayID)
    }

    @objc private func clearAllWallpapers() {
        wallpaperManager.clearAllWallpapers()
    }

    @objc private func togglePause() {
        wallpaperManager.togglePause()
    }

    @objc private func toggleMute() {
        wallpaperManager.toggleMute()
    }

    @objc private func setModeAllDisplays() {
        wallpaperManager.setMode(.allDisplays)
    }

    @objc private func setModePerDisplay() {
        wallpaperManager.setMode(.perDisplay)
    }

    @objc private func checkForUpdates() {
        updater.checkForUpdates()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
