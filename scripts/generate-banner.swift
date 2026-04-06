#!/usr/bin/env swift
//
// generate-banner.swift
// Generates an 8-bit pixel art banner: app icon + "MOVING PAPER" text.
// Output: build/banner.png (800x200, transparent background)
//
// Usage: swift scripts/generate-banner.swift

import AppKit
import Foundation

// MARK: - 5x7 Pixel Font (uppercase only)

let glyphs: [Character: [String]] = [
    "M": [
        "#...#",
        "##.##",
        "#.#.#",
        "#...#",
        "#...#",
        "#...#",
        "#...#",
    ],
    "O": [
        ".###.",
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        ".###.",
    ],
    "V": [
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        ".#.#.",
        ".#.#.",
        "..#..",
    ],
    "I": [
        "###",
        ".#.",
        ".#.",
        ".#.",
        ".#.",
        ".#.",
        "###",
    ],
    "N": [
        "#...#",
        "##..#",
        "##..#",
        "#.#.#",
        "#..##",
        "#..##",
        "#...#",
    ],
    "G": [
        ".###.",
        "#...#",
        "#....",
        "#.##.",
        "#...#",
        "#...#",
        ".###.",
    ],
    "P": [
        "####.",
        "#...#",
        "#...#",
        "####.",
        "#....",
        "#....",
        "#....",
    ],
    "A": [
        ".###.",
        "#...#",
        "#...#",
        "#####",
        "#...#",
        "#...#",
        "#...#",
    ],
    "E": [
        "#####",
        "#....",
        "#....",
        "####.",
        "#....",
        "#....",
        "#####",
    ],
    "R": [
        "####.",
        "#...#",
        "#...#",
        "####.",
        "#.#..",
        "#..#.",
        "#...#",
    ],
    " ": [
        "...",
        "...",
        "...",
        "...",
        "...",
        "...",
        "...",
    ],
]

// MARK: - Rendering

let text = "MOVING PAPER"
let pixelScale = 4       // each font pixel = 4x4 output pixels
let letterSpacing = 1    // pixels between letters
let iconSize = 160       // icon area on the left
let padding = 40         // horizontal padding
let bannerHeight = 200
let textColor = NSColor(red: 0.75, green: 0.82, blue: 0.95, alpha: 1.0)  // soft sky blue to match night theme

// Calculate text width
var textWidth = 0
for ch in text {
    if let g = glyphs[ch] {
        textWidth += g[0].count + letterSpacing
    }
}
textWidth -= letterSpacing  // remove trailing spacing
textWidth *= pixelScale

let bannerWidth = padding + iconSize + padding + textWidth + padding

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: bannerWidth,
    pixelsHigh: bannerHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

cg.setShouldAntialias(false)
cg.interpolationQuality = .none
cg.clear(CGRect(x: 0, y: 0, width: bannerWidth, height: bannerHeight))

// Draw the app icon (load from build/movingpaper.png)
let iconPath = "build/movingpaper.png"
if let iconData = try? Data(contentsOf: URL(fileURLWithPath: iconPath)),
   let iconImage = NSImage(data: iconData) {
    let iconRect = CGRect(
        x: padding,
        y: (bannerHeight - iconSize) / 2,
        width: iconSize,
        height: iconSize
    )
    cg.saveGState()
    cg.interpolationQuality = .high
    cg.setShouldAntialias(true)
    iconImage.draw(in: iconRect)
    cg.restoreGState()
    cg.setShouldAntialias(false)
    cg.interpolationQuality = .none
}

// Draw pixel text
let textStartX = padding + iconSize + padding
let textStartY = (bannerHeight - 7 * pixelScale) / 2  // vertically center the 7-row text

cg.setFillColor(textColor.cgColor)

var cursorX = textStartX
for ch in text {
    guard let glyph = glyphs[ch] else { continue }
    let glyphWidth = glyph[0].count

    for (rowIdx, row) in glyph.enumerated() {
        for (colIdx, pixel) in row.enumerated() where pixel == "#" {
            let x = cursorX + colIdx * pixelScale
            let y = textStartY + (6 - rowIdx) * pixelScale  // flip Y
            cg.fill(CGRect(x: x, y: y, width: pixelScale, height: pixelScale))
        }
    }

    cursorX += (glyphWidth + letterSpacing) * pixelScale
}

NSGraphicsContext.current = nil

// Save
guard let data = rep.representation(using: .png, properties: [:]) else {
    print("ERROR: Failed to create PNG")
    exit(1)
}

try! data.write(to: URL(fileURLWithPath: "build/banner.png"))
print("Wrote build/banner.png (\(bannerWidth)x\(bannerHeight))")
