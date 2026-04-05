#!/usr/bin/env swift
//
// generate-app-icon.swift
// Generates an 8-bit pixel art app icon (folder + film strip) at all required
// sizes for macOS .icns creation. Run from project root:
//
//   swift scripts/generate-app-icon.swift
//   iconutil -c icns build/MovingPaper.iconset -o build/MovingPaper.icns
//

import AppKit
import Foundation

// MARK: - 8-bit Pixel Art Definition

// 32x32 pixel grid — the "master" design, scaled to all output sizes.
// '#' = foreground, '.' = empty, 'T' = folder tab accent, 'F' = film frame hole
let pixelArt: [String] = [
    // Folder tab (rows 0-3)
    "................................",
    "..########......................",
    ".#........#.....................",
    ".#........#.....................",
    // Folder top edge
    "################################",
    "#..............................#",
    // Film strip top perfs
    "#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#",
    // Film strip top bar
    "#.############################.#",
    // Frame row 1 — three film frames (8px each, 1px dividers)
    "#.#........#........#........#.#",
    "#.#........#........#........#.#",
    "#.#........#........#........#.#",
    "#.#........#........#........#.#",
    "#.#........#........#........#.#",
    // Film strip middle bar
    "#.############################.#",
    // Film strip middle perfs
    "#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#",
    // Film strip middle bar
    "#.############################.#",
    // Frame row 2 — three film frames
    "#.#........#........#........#.#",
    "#.#........#........#........#.#",
    "#.#........#........#........#.#",
    "#.#........#........#........#.#",
    "#.#........#........#........#.#",
    // Film strip bottom bar
    "#.############################.#",
    // Film strip bottom perfs
    "#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#",
    // Bottom border
    "#..............................#",
    "################################",
    // Padding
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
]

// MARK: - Color Palette (8-bit retro style)

struct PixelColor {
    let r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat
    var cgColor: CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
}

let folderBody   = PixelColor(r: 0.30, g: 0.65, b: 0.95, a: 1.0)   // bright blue folder
let folderDark   = PixelColor(r: 0.20, g: 0.50, b: 0.80, a: 1.0)   // darker blue edge
let filmStrip    = PixelColor(r: 0.15, g: 0.15, b: 0.20, a: 1.0)   // dark film strip
let filmFrame    = PixelColor(r: 0.85, g: 0.85, b: 0.90, a: 1.0)   // light frame interior
let filmPerf     = PixelColor(r: 0.30, g: 0.65, b: 0.95, a: 1.0)   // perf shows folder behind
let background   = PixelColor(r: 0.0,  g: 0.0,  b: 0.0,  a: 0.0)   // transparent

// MARK: - Rendering

func renderIcon(size: Int) -> NSBitmapImageRep {
    let gridW = 32
    let gridH = 32
    let pixelSize = CGFloat(size) / CGFloat(gridW)

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
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

    // Disable antialiasing for crisp pixel art
    cg.setShouldAntialias(false)
    cg.interpolationQuality = .none

    // Clear to transparent
    cg.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // Draw rounded rect background (subtle, like macOS icon shape)
    let cornerRadius = CGFloat(size) * 0.18
    let bgRect = CGRect(x: 0, y: 0, width: size, height: size)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    cg.addPath(bgPath)
    cg.setFillColor(CGColor(red: 0.12, green: 0.45, blue: 0.85, alpha: 1.0))
    cg.fillPath()

    // Draw pixel grid
    for (rowIdx, row) in pixelArt.enumerated() {
        let y = rowIdx
        for (colIdx, ch) in row.enumerated() {
            let x = colIdx
            let rect = CGRect(
                x: CGFloat(x) * pixelSize,
                y: CGFloat(gridH - 1 - y) * pixelSize,
                width: ceil(pixelSize),
                height: ceil(pixelSize)
            )

            let color: PixelColor
            switch ch {
            case "#":
                if rowIdx <= 4 || rowIdx == 25 {
                    color = folderDark
                } else if rowIdx == 5 || rowIdx == 24 {
                    color = folderBody
                } else {
                    color = filmStrip
                }
            case ".":
                if rowIdx > 4 && rowIdx < 25 {
                    if rowIdx == 6 || rowIdx == 14 || rowIdx == 22 {
                        color = filmPerf
                    } else if (rowIdx >= 8 && rowIdx <= 12) || (rowIdx >= 16 && rowIdx <= 20) {
                        // Inside film frames: col 3-10, 12-19, 21-28
                        let inFrame = (colIdx >= 3 && colIdx <= 10)
                            || (colIdx >= 12 && colIdx <= 19)
                            || (colIdx >= 21 && colIdx <= 28)
                        if inFrame {
                            color = filmFrame
                        } else {
                            color = folderBody
                        }
                    } else {
                        color = folderBody
                    }
                } else if rowIdx >= 1 && rowIdx <= 3 {
                    color = folderBody
                } else {
                    continue
                }
            default:
                continue
            }

            cg.setFillColor(color.cgColor)
            cg.fill(rect)
        }
    }

    NSGraphicsContext.current = nil
    return rep
}

func savePNG(rep: NSBitmapImageRep, to path: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("  wrote \(path)")
    } catch {
        print("  ERROR writing \(path): \(error)")
    }
}

// MARK: - Main

let fm = FileManager.default
let iconsetDir = "build/MovingPaper.iconset"

try? fm.removeItem(atPath: iconsetDir)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// Required sizes for macOS .icns
let sizes: [(name: String, px: Int)] = [
    ("icon_16x16",       16),
    ("icon_16x16@2x",    32),
    ("icon_32x32",       32),
    ("icon_32x32@2x",    64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x",1024),
]

print("Generating 8-bit app icon...")

for entry in sizes {
    let rep = renderIcon(size: entry.px)
    let path = "\(iconsetDir)/\(entry.name).png"
    savePNG(rep: rep, to: path)
}

print("Done. Now run:")
print("  iconutil -c icns build/MovingPaper.iconset -o build/MovingPaper.icns")
