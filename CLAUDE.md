# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build
swift run MovingPaper
swift test              # 50 tests across 11 suites
```

**Local refresh:** After every code change, rebuild and refresh the user's local install:

```bash
./scripts/build-dmg.sh --build-only
osascript -e 'tell application "MovingPaper" to quit' 2>/dev/null; sleep 1
trash "/Applications/MovingPaper.app"
cp -R build/MovingPaper.app "/Applications/MovingPaper.app"
open "/Applications/MovingPaper.app"
```

Two vendored dependencies: Sparkle.framework (`tools/sparkle/`) and yt-dlp binary (`tools/yt-dlp/`). Otherwise pure Apple frameworks via Swift Package Manager. Requires macOS 15.0+ and Swift 6.0+ (strict concurrency). The build script auto-downloads yt-dlp if missing.

## Architecture

MovingPaper is a menu-bar-only macOS app (`LSUIElement = true`) that plays GIFs and videos as animated desktop wallpapers. No Dock icon, no main window.

**Startup flow:** `MovingPaperApp` (@main SwiftUI) -> `AppDelegate` sets `.accessory` activation policy -> creates `WallpaperManager` + `MovingPaperUpdater` -> creates `StatusBarController`.

### Source files

| File | Purpose |
|------|---------|
| `MovingPaperApp.swift` | @main entry, SwiftUI App with Settings scene |
| `AppDelegate.swift` | Creates WallpaperManager, updater, status bar |
| `WallpaperManager.swift` | Central coordinator: file/YouTube/Photos assignments, persistence, space/screen/power tracking |
| `StatusBarController.swift` | Menu bar UI, all user actions |
| `WallpaperPanel.swift` | Borderless NSPanel at desktop level |
| `WallpaperWindowController.swift` | Manages one panel per screen, hosts SwiftUI views |
| `VideoWallpaperView.swift` | Looping video via AVQueuePlayer + AVPlayerLooper |
| `GIFWallpaperView.swift` | Animated GIF via CGAnimateImageAtURLWithBlock |
| `AlbumPickerWindowController.swift` | PHPickerViewController in floating NSPanel, returns single URL |
| `PhotosService.swift` | PhotoKit authorization + random video fetch for shuffle |
| `LoadingOverlayView.swift` | Shimmer loading overlay (dark navy pill, centered on desktop) |
| `YouTubeDownloader.swift` | yt-dlp process runner with progress tracking |
| `YouTubeURLParser.swift` | Regex extraction of YouTube video IDs |
| `MenuBarIcon.swift` | Brand icon loader from resource bundle |
| `MovingPaperUpdater.swift` | Sparkle wrapper (dormant in dev builds) |
| `AppIdentity.swift` | Bundle identifier constants and legacy UserDefaults migration |
| `WallpaperRequestCoordinator.swift` | Tracks in-flight wallpaper assignments with cancellation tokens |
| `ManagedDisplaySpaces.swift` | CGS private API wrappers for macOS Space detection |
| `SettingsView.swift` | Settings scene content (currently minimal) |

### Key design decisions

- **Desktop-level windowing:** `WallpaperPanel` (NSPanel) sits at `CGWindowLevelForKey(.desktopWindow) + 1` -- above the system wallpaper but below Finder icons. `ignoresMouseEvents = true` keeps the desktop interactive.
- **Per-desktop wallpapers:** `WallpaperManager.desktopFiles` uses a `[DesktopKey: URL]` dictionary where `DesktopKey` combines `CGDirectDisplayID` + space ID. Two modes: `.allDesktops` (one file everywhere) and `.perDesktop` (different file per screen + Space, like native macOS).
- **Persistence:** Wallpaper assignments, mode, and mute state are saved to `UserDefaults` and restored on launch. Integer types use `NSNumber` wrappers for safe round-tripping (`uint32Value`/`uint64Value`). File paths verified with `FileManager.fileExists` before restore.
- **Space tracking:** `CGSGetActiveSpace` (stable CoreGraphics private API) detects the active macOS Space. `activeSpaceDidChangeNotification` triggers content swap when switching Spaces.
- **One panel per display:** `WallpaperManager` maintains a `[CGDirectDisplayID: WallpaperWindowController]` dictionary. `rebuildAllWindows()` reuses existing controllers when the URL hasn't changed (avoids video reload flash). In `.allDesktops` mode, space changes skip rebuild entirely since panels have `.canJoinAllSpaces`. Each controller tracks its `currentURL` to enable this comparison.
- **SwiftUI content in AppKit shell:** `WallpaperWindowController` hosts SwiftUI views (`VideoWallpaperView`, `GIFWallpaperView`) inside `NSHostingView` attached to the panel.
- **Video looping:** `AVQueuePlayer` + `AVPlayerLooper` for gapless seamless loops. Hardware-accelerated via `AVPlayerLayer`.
- **GIF animation:** `CGAnimateImageAtURLWithBlock` (ImageIO) handles frame timing natively. Frames render into a `CALayer`. A `stopped` flag signals the callback to halt; `removeFromSuperview()` calls `stopAnimation()`.
- **Sound control:** `WallpaperManager.toggleMute()` walks the view hierarchy to find `VideoPlayerNSView` instances and calls `setMuted()` directly. Does NOT rebuild windows -- no teardown, no video interruption.
- **Power awareness:** Playback auto-pauses on Low Power Mode and thermal throttling (serious/critical). Resumes when conditions clear.
- **Auto-updates:** `MovingPaperUpdater` wraps Sparkle's `SPUStandardUpdaterController` for native macOS update alerts. Dormant in dev builds (no bundle = no crash). EdDSA-signed appcast via `scripts/generate-appcast.sh` using Sparkle's `generate_appcast` tool for signed feeds (`SURequireSignedFeed = true`). Public key baked into build script default. `SPUStandardUserDriverDelegate` manages activation policy: promotes to `.regular` when an update session shows its window (so it appears in Dock and Cmd+Tab), restores `.accessory` when the session finishes. `AppDelegate.installApplicationIcon()` sets `NSApp.applicationIconImage` from the bundled `movingpaper-icon.png` (1024x1024) so Sparkle dialogs have a high-res icon without requiring a Dock entry. Release notes HTML uses `@media (prefers-color-scheme: dark)` for readable contrast in dark mode.
- **YouTube wallpapers:** `YouTubeDownloader` runs yt-dlp (downloaded on first use to `~/Library/Application Support/MovingPaper/`) via `Process` to download videos as local MP4 (up to 1080p). `YouTubeURLParser` extracts video IDs from all YouTube URL formats. Cache at `~/Library/Application Support/MovingPaper/YouTube/{videoID}.mp4` with deduplication. YouTube URLs persisted alongside file paths for re-download if cache cleared. Process environment includes `/opt/homebrew/bin` for ffmpeg access.
- **Photos integration:** Two features, no playlists. "Choose from Photos" uses `PHPickerViewController` (no authorization needed) to pick ONE video, which loops like any file. "Shuffle from Photos" uses `PhotosService` (requires Photos library authorization via `NSPhotoLibraryUsageDescription`) to fetch a random video from the entire library, export it via `AVAssetExportSession` to a local `.mp4` cache at `~/Library/Application Support/MovingPaper/PhotosShuffle/`, and set it as wallpaper. Must use `requestExportSession` + `session.export(to:as:)`, NOT `requestAVAsset` -- the latter returns `AVComposition` (not `AVURLAsset`) for edited/slow-mo videos and silently fails. Exports are cached by asset ID. The app must activate (`.regular` policy) before requesting Photos authorization so the system prompt can appear.
- **Loading overlay:** `LoadingOverlayController` manages a floating `NSPanel` at `.screenSaver` level (above all windows) that shows a dark navy pill with white shimmer text. The sheen sweeps left-to-right across the text continuously. Appears automatically during YouTube downloads (with progress bar via Combine observer on `YouTubeDownloader.$state`) and Photos shuffle. Fades in/out with eased timing, then closes the old panel so transient overlays do not accumulate. Brand colors: bg `(0.04, 0.06, 0.14)`, accent `(0.55, 0.65, 0.90)`.
- **Menu bar:** Uses "MovingPaper" instead of "Wallpaper" in menu text (e.g., "No MovingPaper", "MovingPaper Mode", "Remove MovingPaper"). The menu includes an explicit `Settings...` action because this is an `.accessory` app with no main window. Per-desktop mode shows `Desktop N: filename` with submenus per Space, and long file/display names are middle-truncated to keep menu labels scannable. Menu rebuilds debounced via `Publishers.MergeMany` + 50ms debounce. Brand icon loaded at 22x22, full color (not template).
- **DMG packaging:** App bundle is `MovingPaper.app` everywhere (build output, DMG, `/Applications/`). All build artifacts go to `build/`.

### Critical patterns

**Activation policy for menu-triggered windows:** Menu-bar-only apps (`.accessory`) lose focus when the menu closes. Any window shown from a menu action must: (1) set `NSApp.setActivationPolicy(.regular)` + `NSApp.activate()` **synchronously** in the `@objc` handler, BEFORE any `Task` or async gap, and (2) reset to `.accessory` when the window closes or the action completes. The caller is responsible for the reset, not the window. This also applies to system permission prompts (e.g., Photos authorization) -- they will not appear unless the app is activated first. **Exception:** Sparkle update presentation is handled by `SPUStandardUserDriverDelegate` in `MovingPaperUpdater`, not manual policy toggling -- it promotes to `.regular` when an update session window appears and restores `.accessory` when the session finishes.

**View cleanup on teardown:** Both `VideoPlayerNSView` and `GIFAnimationNSView` override `removeFromSuperview()` to stop playback and release resources. Without this, AVPlayers continue decoding and GIF animations keep running after `tearDownWindows()`.

**Mute without rebuild:** `toggleMute()` must NOT call `rebuildAllWindows()`. It walks the view hierarchy via `applyMuteState(to:)` to find `VideoPlayerNSView` and calls `setMuted()` in-place. Rebuilding causes video clipping/freezing.

**Concurrency model:** All UI types are `@MainActor`. Notification observers use `queue: .main` but still require `Task { @MainActor in }` wrappers because the closure is `@Sendable` (Swift 6 strict concurrency). Do not remove the Task wrappers -- they are required to satisfy actor isolation.

**Space changes must not flash:** In `.allDesktops` mode, the space change observer must NOT call `rebuildAllWindows()` -- panels already have `.canJoinAllSpaces`. In `.perDesktop` mode, `rebuildAllWindows()` reuses controllers whose `currentURL` matches, only swapping content when the URL differs. Never tear down a controller just to recreate it with the same video.

**Screen changes in all-desktops mode must persist:** When displays are attached or removed, reconcile the per-display assignment maps and call `saveState()`. Updating the in-memory dictionaries without persisting them causes restored wallpapers to drift from the current monitor topology on next launch.

**Mutual exclusivity of wallpaper sources:** `setWallpaper()` clears both `youtubeURLs` and other state for the affected keys. Each desktop key can have exactly one source: a file, a YouTube URL, or a Photos video. When setting one, clear the others.

## Versioning

Version format is `X.XXX` (e.g., `0.001`, `0.002`). The build script auto-increments on each release build. Source of truth: `sources/Resources/Info.plist` `CFBundleShortVersionString`.

## Release Build

```bash
./scripts/release-movingpaper.sh     # full: bump + build + sign + DMG + notarize + commit + tag + push + GitHub release
./scripts/build-dmg.sh               # packaging only: build + sign + DMG + notarize (no version bump, no git)
./scripts/build-dmg.sh --local       # sign + DMG, skip notarization
./scripts/build-dmg.sh --unsigned    # ad-hoc sign, no Developer ID
./scripts/build-dmg.sh --build-only  # assemble .app only, no DMG
```

`release-movingpaper.sh` owns the full release lifecycle: increments the version (`.001`), calls `build-dmg.sh` to package, updates `Info.plist` and `README.md` download link, commits, tags, pushes, and creates the GitHub release with DMG + SHA + appcast assets. `build-dmg.sh` is packaging-only -- it generates the app icon from `build/movingpaper.png`, builds a release binary, assembles the `.app` bundle with Sparkle.framework, signs everything (Sparkle nested components inside-out), creates a DMG, optionally notarizes, and generates an EdDSA-signed appcast.

Output: `build/MovingPaper.app`, `build/MovingPaper-{version}.dmg`, `build/MovingPaper-{version}.sha256`, `build/appcast.xml`.

**Naming convention:** Brand asset filenames use lowercase (`movingpaper.png`, `movingpaper-dmg-background.png`). Build output filenames that use the product name use PascalCase (`MovingPaper.app`, `MovingPaper.icns`, `MovingPaper-{version}.dmg`). The `build/` directory holds both brand assets (tracked in git) and build artifacts (gitignored). The build script's clean step preserves all `.png` files.

Use `/build-moving-paper` for the full release workflow (build, commit, push, GitHub Release).

Notarization uses the shared `YEN-Notarization` keychain profile (same as YenChat and Kindred). Override with `MOVINGPAPER_NOTARY_PROFILE` env var if needed.

## Brand and Voice

MovingPaper is built by 8BIT (yo gg llc). User-facing text should be friendly, clear, and non-technical. Think "made by someone who loves their desktop" not "enterprise software."

**Commit messages:** Use conventional commit prefixes (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `build:`, `test:`, `ci:`, `style:`). This matters because the Sparkle auto-updater generates release notes from git history. Only `feat:` and `fix:` commits show in the update dialog -- everything else is filtered. Internal/developer changes (`refactor:`, `chore:`, `docs:`, `build:`, `ci:`, `style:`, `test:`) are hidden from users.

**Release notes style:** User-facing, feature-focused. Capitalize first letter of each bullet. No file paths, no code references, no developer jargon. Say "Paste a YouTube URL as your wallpaper" not "Add YouTubeDownloader with yt-dlp Process integration." The footer reads: "MovingPaper {version} -- your desktop, alive."

**"Built with YEN"** link in the menu bar opens https://yen.chat.

## Supported File Types

- Video: `.mov`, `.mp4`, `.m4v` (including HEVC with alpha)
- GIF: `.gif`
- YouTube: paste any `youtube.com/watch`, `youtu.be`, or `youtube.com/shorts` URL
- Photos: pick a video from your library, or shuffle a random one
