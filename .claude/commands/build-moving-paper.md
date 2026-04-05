Build, sign, package, and ship Moving Paper as a signed DMG.

---

## Local Mode

**Usage:** `/build-moving-paper local`

Local mode builds and packages the DMG but does NOT bump the version, does NOT commit, does NOT push, and does NOT create a GitHub Release. It copies the built app to `/Applications/Moving Paper.app` for immediate manual testing and Sparkle update validation.

Use local mode to:
- Validate the build pipeline
- Install a known version to `/Applications/` so you can later ship a newer version and test that Sparkle detects the update

---

## Rules

1. Sequential only. Never parallelize workflow steps.
2. Always run from the checkout root: `REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"`.
3. Restart from Step 0 on any failure -- do not skip ahead.
4. Never use `git add .` or `git add -A`. Stage explicit paths only.
5. One active run per checkout. The build mutates `Sources/MovingPaper/Resources/Info.plist` (version bump in full mode), `README.md` (download link in full mode), and `dist/`.
6. Do not modify the version bump logic -- `build-dmg.sh` owns the `.001` increment.
7. Full mode commits Info.plist and README.md together.
8. Full mode must preserve `/Applications/Moving Paper.app` so the installed copy stays on the older version and can receive the Sparkle update.

---

## Canonical Steps

### Step 0: Preflight

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
echo "Checkout root: $(pwd)"
swift --version
security find-identity -p codesigning -v | grep "Developer ID Application" || echo "WARN: No Developer ID found -- will ad-hoc sign"
test -f Package.swift || { echo "ERROR: Not in Moving Paper repo root"; exit 1; }
test -f scripts/build-dmg.sh || { echo "ERROR: Build script missing"; exit 1; }
test -f MovingPaper.entitlements || { echo "ERROR: Entitlements missing"; exit 1; }
```

In full mode, also verify `gh`:
```bash
gh --version || { echo "ERROR: gh CLI required for GitHub Release"; exit 1; }
```

Check for unstaged changes to files the build will modify:
```bash
git diff --name-only Sources/MovingPaper/Resources/Info.plist README.md
```

If either file has unstaged changes, warn the user and ask whether to proceed.

### Step 1: Read Current Version

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/MovingPaper/Resources/Info.plist)
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Sources/MovingPaper/Resources/Info.plist)
echo "Current: v${CURRENT_VERSION} (build ${CURRENT_BUILD})"
```

In full mode: show the user the next version (current + .001) and confirm before proceeding.
In local mode: tell the user the build will use the CURRENT version without bumping.

### Step 2: Build and Package

**Full mode** (bumps version):
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
./scripts/build-dmg.sh 2>&1
```

**Local mode** (freezes current version):
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/MovingPaper/Resources/Info.plist)
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Sources/MovingPaper/Resources/Info.plist)
MOVINGPAPER_VERSION="$CURRENT_VERSION" MOVINGPAPER_BUILD="$CURRENT_BUILD" ./scripts/build-dmg.sh --local 2>&1
```

By passing `MOVINGPAPER_VERSION` and `MOVINGPAPER_BUILD`, the build script skips the auto-increment and uses the current version as-is.

### Step 3: Verify Build Output

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
BUILT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/MovingPaper/Resources/Info.plist)
echo "Built version: v${BUILT_VERSION}"
ls -lh dist/
codesign --verify --strict dist/MovingPaper.app 2>&1
```

Verify:
- `dist/MovingPaper.app` exists and signature is valid
- `dist/MovingPaper-{version}.dmg` exists
- `dist/MovingPaper-{version}.sha256` exists

### Step 4 (local mode only): Install to /Applications

Copy the built app to `/Applications/` for Sparkle testing:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
pkill -f "Moving Paper" 2>/dev/null || true
sleep 1
cp -R dist/MovingPaper.app "/Applications/Moving Paper.app"
echo "Installed to /Applications/Moving Paper.app"
open "/Applications/Moving Paper.app"
```

**Stop here in local mode.** Report the installed version and app location.

### Step 5 (full mode): Commit Version Bump + README

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
NEW_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/MovingPaper/Resources/Info.plist)
git add Sources/MovingPaper/Resources/Info.plist README.md
git commit -m "release: Moving Paper v${NEW_VERSION}"
```

### Step 6 (full mode): Push

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
git push origin HEAD
```

### Step 7 (full mode): Create GitHub Release

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
NEW_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/MovingPaper/Resources/Info.plist)
DMG_FILE="dist/MovingPaper-${NEW_VERSION}.dmg"
SHA_FILE="dist/MovingPaper-${NEW_VERSION}.sha256"

gh release create "v${NEW_VERSION}" \
    --title "Moving Paper v${NEW_VERSION}" \
    --notes "Moving Paper v${NEW_VERSION}

Download the DMG, open it, and drag Moving Paper.app to /Applications.

**SHA-256:** $(cat "$SHA_FILE")" \
    "$DMG_FILE" \
    "$SHA_FILE"
```

Verify:
```bash
gh release view "v${NEW_VERSION}"
```

### Step 8 (full mode): Verify Download URL

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
NEW_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/MovingPaper/Resources/Info.plist)
DOWNLOAD_URL="https://github.com/8bittts/moving-paper/releases/download/v${NEW_VERSION}/MovingPaper-${NEW_VERSION}.dmg"
curl -sI -o /dev/null -w "%{http_code}" -L "$DOWNLOAD_URL"
```

A `200` confirms the DMG is downloadable.

### Step 9 (full mode): Report

```
Moving Paper v{version} (build {build})
  App:      dist/MovingPaper.app
  DMG:      dist/MovingPaper-{version}.dmg
  SHA:      {checksum}
  Signed:   {identity}
  Release:  https://github.com/8bittts/moving-paper/releases/tag/v{version}
  Download: https://github.com/8bittts/moving-paper/releases/download/v{version}/MovingPaper-{version}.dmg
  Pushed:   {branch}
```
