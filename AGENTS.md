# Repository Guidelines

## Project Structure & Module Organization

`MovingPaper` is a Swift Package Manager macOS app. The package manifest lives in `Package.swift`. Application code is under `sources/`, with one type per file and clear platform splits such as `WallpaperManager.swift`, `StatusBarController.swift`, `VideoWallpaperView.swift`, and `GIFWallpaperView.swift`. Bundle resources live in `sources/Resources/`, including `Info.plist`. Root-level `test-wallpaper.gif` and `test-wallpaper.mp4` are useful manual test assets. Tests live in `tests/`.

## Build, Test, and Development Commands

Run from the repository root:

- `swift build` compiles the app in debug mode.
- `swift run MovingPaper` launches the menu bar app locally.
- `swift test` runs 50 tests across 11 suites, including reconciliation and menu label formatting coverage in addition to the existing wallpaper, display ID, icon, parser, and versioning suites.

Use macOS 15+ and Swift 6, matching `Package.swift` and the README.

## Coding Style & Naming Conventions

Follow the existing Swift style:

- Use 4-space indentation and keep lines readable rather than tightly packed.
- Use `UpperCamelCase` for types and `lowerCamelCase` for properties and methods.
- Keep UI-facing classes on the main actor when appropriate, as in `@MainActor final class WallpaperManager`.
- Prefer small files with focused responsibilities and organize larger files with `// MARK:` sections.
- Add comments only where behavior is non-obvious, especially around AppKit window levels, power-state handling, and screen lifecycle code.

## Testing Guidelines

Tests live in `tests/` using Swift Testing (`@Test`). Name files after the type under test (e.g., `WallpaperFileTypeTests.swift`). Prioritize file-type detection, pause/resume behavior, power-aware throttling, persistence round-tripping, multi-display rebuilds, and menu-bar label formatting/reconciliation helpers. For UI-heavy changes, also verify manually using the sample wallpaper files in the repo root.

## Persistence

Wallpaper assignments, mode, and mute state persist to `UserDefaults`. Integer types (`CGDirectDisplayID` as UInt32, space ID as UInt64) must use `NSNumber` wrappers for safe round-tripping -- direct `as?` casts fail after serialization. File paths use `url.path(percentEncoded: false)` and reconstruct via `URL(filePath:)`. Restored entries are skipped if the file no longer exists on disk. YouTube URLs are stored alongside file paths as an optional `"youtubeURL"` key; if the cached file is missing on restore, the video is re-downloaded automatically.

## YouTube Integration

YouTube wallpapers are downloaded via a bundled `yt-dlp` binary (`tools/yt-dlp/yt-dlp`, auto-downloaded by `build-dmg.sh` if missing). `YouTubeURLParser` extracts 11-character video IDs from all standard YouTube URL formats. `YouTubeDownloader` runs `yt-dlp` via `Process`, reports progress via `@Published state`, and caches downloads to `~/Library/Application Support/MovingPaper/YouTube/{videoID}.mp4`. The format flag `best[ext=mp4][height<=1080]` avoids needing ffmpeg for stream merging. Tests for the URL parser duplicate the parser logic to avoid importing the main module (which requires Sparkle at compile time).

## Commit & Pull Request Guidelines

Recent history uses short, prefixed subjects such as `docs: rewrite README` and `init: animated wallpaper engine prototype`. Keep that pattern with imperative summaries like `fix: rebuild wallpaper windows on display change`. Pull requests should include a brief description, linked issue if applicable, manual test notes, and screenshots or recordings for visible menu bar or wallpaper behavior changes.
