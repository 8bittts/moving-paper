#!/usr/bin/env swift
//
// generate-app-icon.swift
// Scales brand/moving-paper.png to all required sizes for macOS .icns creation.
//
//   swift scripts/generate-app-icon.swift
//   iconutil -c icns build/MovingPaper.iconset -o build/MovingPaper.icns

import AppKit
import Foundation

let sourcePath = "brand/moving-paper.png"
let iconsetDir = "build/MovingPaper.iconset"

guard let sourceData = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)),
      let sourceImage = NSImage(data: sourceData) else {
    print("ERROR: Could not load \(sourcePath)")
    exit(1)
}

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetDir)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

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

print("Generating app icon from \(sourcePath)...")

for entry in sizes {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: entry.px,
        pixelsHigh: entry.px,
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

    // High-quality scaling for the pixel art
    ctx.imageInterpolation = .none  // nearest-neighbor preserves pixel art
    sourceImage.draw(in: NSRect(x: 0, y: 0, width: entry.px, height: entry.px))

    NSGraphicsContext.current = nil

    let path = "\(iconsetDir)/\(entry.name).png"
    if let data = rep.representation(using: .png, properties: [:]) {
        try! data.write(to: URL(fileURLWithPath: path))
        print("  wrote \(path)")
    }
}

print("Done. Now run:")
print("  iconutil -c icns build/MovingPaper.iconset -o build/MovingPaper.icns")
