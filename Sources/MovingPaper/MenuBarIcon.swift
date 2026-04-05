import AppKit

/// Generates 8-bit pixel art menu bar icons programmatically via CoreGraphics.
/// Template images adapt automatically to light/dark menu bar.
enum MenuBarIcon {

    /// 8-bit retro folder with film strip — the Moving Paper brand glyph.
    /// Rendered as a template image so macOS handles light/dark automatically.
    static func folderFilm(size: CGFloat = 18) -> NSImage {
        // Pixel grid: 16x14 logical pixels, scaled to requested size
        let gridW = 16
        let gridH = 14
        let scale = size / CGFloat(gridW)

        let image = NSImage(size: NSSize(width: CGFloat(gridW) * scale, height: CGFloat(gridH) * scale))
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let black = NSColor.black.cgColor
        ctx.setFillColor(black)

        // Each row is a string of 16 chars: '#' = filled, '.' = empty
        // Design: folder tab top, folder body, film strip perforations inside
        let pixels: [String] = [
            // Row 0-1: folder tab
            "..#####.........",
            ".#.....#........",
            // Row 2: folder top edge
            "################",
            // Row 3: folder body with film strip top perfs
            "#.#.##.##.##.#.#",
            // Row 4: film strip bar
            "#.############.#",
            // Row 5-6: film frames (two frames)
            "#.##...##...##.#",
            "#.##...##...##.#",
            // Row 7: film strip middle bar
            "#.############.#",
            // Row 8-9: film frames (two frames)
            "#.##...##...##.#",
            "#.##...##...##.#",
            // Row 10: film strip bar
            "#.############.#",
            // Row 11: film strip bottom perfs
            "#.#.##.##.##.#.#",
            // Row 12: folder bottom edge
            "################",
            // Row 13: empty (padding)
            "................",
        ]

        for (y, row) in pixels.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" {
                let rect = CGRect(
                    x: CGFloat(x) * scale,
                    y: CGFloat(gridH - 1 - y) * scale,  // flip Y for CG coords
                    width: scale,
                    height: scale
                )
                ctx.fill(rect)
            }
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    /// Smaller variant for compact menu bars.
    static func folderFilmSmall() -> NSImage {
        folderFilm(size: 16)
    }
}
