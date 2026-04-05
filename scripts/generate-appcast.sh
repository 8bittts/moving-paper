#!/usr/bin/env bash
#
# generate-appcast.sh — Generate a Sparkle appcast.xml for Moving Paper.
#
# Usage:
#   ./scripts/generate-appcast.sh
#
# Reads version/build from the built app bundle in dist/, signs the DMG
# with Sparkle's EdDSA tool, and outputs dist/appcast.xml.
#
# Environment:
#   MOVINGPAPER_APPCAST_DOWNLOAD_BASE   Override base URL for DMG download
#                                        (default: GitHub Releases)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# ── Constants ────────────────────────────────────────────────────────────────

APP_NAME="MovingPaper"
GITHUB_REPO="8bittts/moving-paper"
SIGN_TOOL="tools/sparkle/bin/sign_update"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

APP_BUNDLE="dist/${APP_NAME}.app"
INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"
OUTPUT="dist/appcast.xml"

# ── Helpers ──────────────────────────────────────────────────────────────────

info()  { printf "\033[1;34m==>\033[0m %s\n" "$1"; }
step()  { printf "\033[1;36m  ->\033[0m %s\n" "$1"; }
fail()  { printf "\033[1;31mERROR:\033[0m %s\n" "$1" >&2; exit 1; }

# ── Validate ─────────────────────────────────────────────────────────────────

[ -d "$APP_BUNDLE" ] || fail "App bundle not found at $APP_BUNDLE — run build-dmg.sh first"
[ -x "$SIGN_TOOL" ] || fail "Sparkle sign_update tool not found at $SIGN_TOOL"

# ── Extract metadata ────────────────────────────────────────────────────────

VERSION="$("$PLIST_BUDDY" -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_NUMBER="$("$PLIST_BUDDY" -c 'Print :CFBundleVersion' "$INFO_PLIST")"
MIN_MACOS="$("$PLIST_BUDDY" -c 'Print :LSMinimumSystemVersion' "$INFO_PLIST")"

DMG_FILENAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="dist/${DMG_FILENAME}"

[ -f "$DMG_PATH" ] || fail "DMG not found at $DMG_PATH"

info "Generating appcast for Moving Paper v${VERSION} (build ${BUILD_NUMBER})"

# ── Download URL ─────────────────────────────────────────────────────────────

DOWNLOAD_BASE="${MOVINGPAPER_APPCAST_DOWNLOAD_BASE:-https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}}"
DOWNLOAD_URL="${DOWNLOAD_BASE}/${DMG_FILENAME}"
step "Download URL: ${DOWNLOAD_URL}"

# ── File size ────────────────────────────────────────────────────────────────

FILE_SIZE=$(stat -f%z "$DMG_PATH")
step "File size: ${FILE_SIZE} bytes"

# ── EdDSA signature ─────────────────────────────────────────────────────────

info "Signing DMG with Sparkle EdDSA"
sign_output="$("$SIGN_TOOL" "$DMG_PATH" 2>&1)"
ed_signature="$(printf '%s\n' "$sign_output" | grep -o 'sparkle:edSignature="[^"]*"' | /usr/bin/sed 's/sparkle:edSignature="\([^"]*\)"/\1/' | head -1)"

if [ -z "$ed_signature" ]; then
    fail "Failed to generate EdDSA signature. Output: $sign_output"
fi
step "EdDSA signature: ${ed_signature:0:40}..."

# ── Publication date ─────────────────────────────────────────────────────────

pub_date="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"

# ── Generate appcast XML ────────────────────────────────────────────────────

cat > "$OUTPUT" <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Moving Paper Updates</title>
        <description>Moving Paper update feed.</description>
        <language>en</language>
        <item>
            <title>Moving Paper ${VERSION}</title>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>${MIN_MACOS}</sparkle:minimumSystemVersion>
            <pubDate>${pub_date}</pubDate>
            <description><![CDATA[
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 14px; }
                    h2 { margin: 0 0 10px 0; font-size: 16px; }
                </style>
                <h2>Moving Paper ${VERSION}</h2>
                <p>Animated desktop wallpapers for macOS.</p>
            ]]></description>
            <enclosure
                url="${DOWNLOAD_URL}"
                length="${FILE_SIZE}"
                type="application/x-apple-diskimage"
                sparkle:edSignature="${ed_signature}" />
        </item>
    </channel>
</rss>
APPCAST

# Validate XML
if command -v xmllint &>/dev/null; then
    xmllint --noout "$OUTPUT" 2>&1 && step "XML validated"
fi

info "Appcast generated: ${OUTPUT}"
