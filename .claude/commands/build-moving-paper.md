Build, sign, package, and ship Moving Paper as a signed DMG.

---

## Local Mode

**Usage:** `/build-moving-paper local`

Local mode runs the full build and packaging pipeline but skips notarization, does not create a GitHub Release, does not commit, and does not push. Use it to validate the build locally.

---

## Rules

1. Sequential only. Never parallelize workflow steps.
2. Always run from the checkout root: `REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"`.
3. Restart from Step 0 on any failure -- do not skip ahead.
4. Never use `git add .` or `git add -A`. Stage explicit paths only.
5. One active run per checkout. The build mutates `Sources/MovingPaper/Resources/Info.plist` (version bump), `README.md` (download link), and `dist/`.
6. Do not modify the version bump logic -- `build-dmg.sh` owns the `.001` increment.
7. The build script also updates README.md with the new version's download link. Both Info.plist and README.md must be committed together.

---

## Canonical Steps (0-8)

### Step 0: Preflight

Validate environment and signing identity before building.

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
echo "Checkout root: $(pwd)"
swift --version
security find-identity -p codesigning -v | grep "Developer ID Application" || echo "WARN: No Developer ID found -- will ad-hoc sign"
test -f Package.swift || { echo "ERROR: Not in Moving Paper repo root"; exit 1; }
test -f scripts/build-dmg.sh || { echo "ERROR: Build script missing"; exit 1; }
test -f MovingPaper.entitlements || { echo "ERROR: Entitlements missing"; exit 1; }
gh --version || { echo "ERROR: gh CLI required for GitHub Release"; exit 1; }
```

Verify the working tree is clean (unstaged changes to Info.plist or README.md will be overwritten by the build):

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

Show the user what the next version will be (current + .001) and confirm before proceeding.

### Step 2: Build and Package

Run the build script. In local mode, pass `--local`. In full mode, run without flags.

**Full mode:**
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
./scripts/build-dmg.sh 2>&1
```

**Local mode:**
```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
./scripts/build-dmg.sh --local 2>&1
```

The script will:
1. Auto-increment version in Info.plist (e.g., 0.001 -> 0.002)
2. Auto-increment build number
3. Generate the 8-bit app icon
4. Build a release binary via `swift build -c release`
5. Assemble the .app bundle with icon, Info.plist, and entitlements
6. Code sign with Developer ID (or ad-hoc if unavailable)
7. Create a DMG with drag-to-Applications layout
8. Sign the DMG
9. Notarize and staple (full mode only)
10. Generate SHA-256 checksum
11. Update README.md with the new version's download link

### Step 3: Verify Build Output

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
NEW_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/MovingPaper/Resources/Info.plist)
echo "Built version: v${NEW_VERSION}"
ls -lh dist/
codesign --verify --strict dist/MovingPaper.app 2>&1
grep "download-link" README.md
```

Verify:
- [ ] `dist/MovingPaper.app` exists and signature is valid
- [ ] `dist/MovingPaper-{version}.dmg` exists
- [ ] `dist/MovingPaper-{version}.sha256` exists
- [ ] Version in Info.plist was incremented
- [ ] README.md download link updated to new version

If local mode, stop here. Report the build output to the user.

### Step 4: Commit Version Bump + README

Stage the version-bumped Info.plist and the updated README.md. Do not stage build artifacts.

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
NEW_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/MovingPaper/Resources/Info.plist)
git add Sources/MovingPaper/Resources/Info.plist README.md
git commit -m "release: Moving Paper v${NEW_VERSION}"
```

### Step 5: Push

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
git push origin HEAD
```

### Step 6: Create GitHub Release

Create a tagged release and upload the DMG as a release asset.

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

Verify the release was created:

```bash
gh release view "v${NEW_VERSION}"
```

### Step 7: Verify Download URL

Confirm the DMG download URL in README.md resolves correctly:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel)" && cd "$REPO_ROOT"
NEW_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/MovingPaper/Resources/Info.plist)
DOWNLOAD_URL="https://github.com/8bittts/moving-paper/releases/download/v${NEW_VERSION}/MovingPaper-${NEW_VERSION}.dmg"
curl -sI -o /dev/null -w "%{http_code}" -L "$DOWNLOAD_URL"
```

A `200` confirms the DMG is downloadable from the URL linked in README.md.

### Step 8: Report

Print a summary:

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
