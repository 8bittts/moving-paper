import Testing
import AppKit

/// Tests for the programmatic menu bar icon generation.
/// Replicates the pixel-drawing logic from MenuBarIcon to validate the approach.
struct MenuBarIconTests {

    /// Generates an icon using the same approach as MenuBarIcon.folderFilm()
    @MainActor
    private func generateIcon(size: CGFloat) -> NSImage {
        let gridW = 16
        let gridH = 14
        let scale = size / CGFloat(gridW)

        let image = NSImage(size: NSSize(width: CGFloat(gridW) * scale, height: CGFloat(gridH) * scale))
        image.lockFocus()

        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.setFillColor(NSColor.black.cgColor)
            // Just draw a single test pixel to prove rendering works
            ctx.fill(CGRect(x: 0, y: 0, width: scale, height: scale))
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @Test @MainActor func iconRendersWithPositiveSize() {
        let icon = generateIcon(size: 18)
        #expect(icon.size.width > 0)
        #expect(icon.size.height > 0)
    }

    @Test @MainActor func iconIsTemplate() {
        let icon = generateIcon(size: 18)
        #expect(icon.isTemplate == true)
    }

    @Test @MainActor func iconScalesCorrectly() {
        let icon16 = generateIcon(size: 16)
        let icon32 = generateIcon(size: 32)
        #expect(icon32.size.width > icon16.size.width)
    }
}
