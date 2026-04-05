<p align="center">
  <img src="brand/moving-paper.png" alt="Moving Paper" width="200">
</p>

<h1 align="center">Moving Paper</h1>

<p align="center">
  A moving (wall)paper for your desktop.
</p>

<p align="center">
  <!-- version-badge -->v0.002<!-- /version-badge --> · macOS 15+ · Swift 6 · MIT
</p>

---

## The Story

I just wanted a simple way to animate my wallpaper while I code. No bloated app, no subscription, no electron wrapper -- just a native macOS menu bar utility that plays a video or GIF behind my desktop icons. That's it. That's the whole project.

The name is literal: it's your wallpaper, but it moves. Moving (Wall) Paper. **Moving Paper**.

---

## Download

<!-- download-link -->[**Download Moving Paper v0.002**](https://github.com/8bittts/moving-paper/releases/download/v0.002/MovingPaper-0.002.dmg)<!-- /download-link -->

Open the `.dmg`, drag **Moving Paper** to Applications, launch it. Look for the pixel art icon in your menu bar -- that's it, you're done.

> Code-signed and notarized. If macOS still warns you, right-click the app and choose "Open".

---

## What It Does

Moving Paper places a looping video or animated GIF as your desktop background. Your icons, right-click menus, and drag-and-drop all work normally -- the animation sits underneath everything.

| Format | Extensions | Notes |
|--------|-----------|-------|
| Video  | `.mp4`, `.mov`, `.m4v` | Seamless gapless looping, HEVC with alpha |
| GIF    | `.gif` | Native frame timing |

## Features

- **Per-display wallpapers** -- different wallpaper on each monitor, just like native macOS
- **Sound control** -- mute or unmute video audio from the menu (muted by default)
- **Multi-monitor** -- auto-detects displays, rebuilds on hot-plug and resolution changes
- **Power-aware** -- pauses on Low Power Mode and thermal throttling, resumes when clear
- **Auto-updates** -- built-in Sparkle updater
- **Menu bar only** -- no Dock icon, no window, no clutter

## Menu

Click the icon in your menu bar:

| Item | What it does |
|------|-------------|
| **Choose File...** | Pick a `.gif`, `.mp4`, `.mov`, or `.m4v` |
| **Sound: Off / On** | Toggle video audio |
| **Wallpaper Mode >** | All Displays (one everywhere) or Per Display (different per screen) |
| **Pause / Resume** | Stop or restart playback |
| **Remove Wallpaper** | Clear and tear down |
| **Check for Updates...** | Manual Sparkle update check |
| **Quit Moving Paper** | Exit |

---

## Build from Source

Requires macOS 15.0+ (Sequoia) and Swift 6.0+.

```bash
git clone https://github.com/8bittts/moving-paper.git
cd moving-paper
swift build
swift run MovingPaper
```

### Tests

```bash
swift test
```

### Signed DMG

```bash
./scripts/build-dmg.sh            # build + sign + DMG + notarize
./scripts/build-dmg.sh --local    # skip notarization
./scripts/build-dmg.sh --unsigned # ad-hoc sign only
```

Version auto-increments on each build (`0.001` -> `0.002` -> ...) and the download link in this README updates automatically.

---

## How It Works

A borderless `NSPanel` at `desktopWindow + 1` -- above the system wallpaper, below Finder icons. `ignoresMouseEvents = true` keeps your desktop interactive. Video loops via `AVQueuePlayer` + `AVPlayerLooper`. GIFs animate via `CGAnimateImageAtURLWithBlock`. One panel per connected display, rebuilt on screen changes. All public Apple APIs, no private frameworks.

## Tech Stack

| | |
|---|---|
| Build | Swift Package Manager |
| Windowing | AppKit (NSPanel, NSStatusItem) |
| UI | SwiftUI via NSHostingView |
| Video | AVFoundation |
| GIF | ImageIO |
| Updates | [Sparkle](https://sparkle-project.org) |

## Contributing

Fork, branch, `swift test`, PR. One feature or fix per PR.

## License

[MIT](LICENSE)
