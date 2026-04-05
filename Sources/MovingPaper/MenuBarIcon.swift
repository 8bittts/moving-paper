import AppKit

/// Generates the Moving Paper menu bar icon programmatically.
/// Template images adapt automatically to light/dark menu bar.
enum MenuBarIcon {

    /// Night sky with clouds — matches the Moving Paper brand.
    /// Rendered as a template image so macOS handles light/dark automatically.
    static func brandIcon(size: CGFloat = 18) -> NSImage {
        let gridW = 16
        let gridH = 16
        let scale = size / CGFloat(gridW)

        let image = NSImage(size: NSSize(width: CGFloat(gridW) * scale, height: CGFloat(gridH) * scale))
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        ctx.setFillColor(NSColor.black.cgColor)

        // 16x16 pixel grid: night sky scene with stars and clouds
        // '#' = filled (dark), '.' = empty (transparent)
        let pixels: [String] = [
            // Stars in sky
            "................",
            "..#.........#...",
            "................",
            ".........#......",
            "....#...........",
            "...............#",
            ".#..........#...",
            "..........#.....",
            // Cloud layer (fluffy tops)
            "......####......",
            "....########....",
            "..############..",
            ".##############.",
            "################",
            "################",
            "################",
            "################",
        ]

        for (y, row) in pixels.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" {
                let rect = CGRect(
                    x: CGFloat(x) * scale,
                    y: CGFloat(gridH - 1 - y) * scale,
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
}
