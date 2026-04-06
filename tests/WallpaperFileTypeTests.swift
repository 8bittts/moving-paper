import Testing
import Foundation

/// Tests for wallpaper file type detection logic.
/// Mirrors the extension-based detection in WallpaperManager.fileType(for:).
struct WallpaperFileTypeTests {

    // MARK: - File Type Detection

    enum FileType: Equatable {
        case gif, video
    }

    /// Replicates the file type detection from WallpaperManager
    private func detectFileType(for url: URL) -> FileType? {
        switch url.pathExtension.lowercased() {
        case "gif":            return .gif
        case "mov", "mp4", "m4v": return .video
        default:               return nil
        }
    }

    @Test func gifDetection() {
        let url = URL(fileURLWithPath: "/tmp/test.gif")
        #expect(detectFileType(for: url) == .gif)
    }

    @Test func gifDetectionUppercase() {
        let url = URL(fileURLWithPath: "/tmp/test.GIF")
        #expect(detectFileType(for: url) == .gif)
    }

    @Test func mp4Detection() {
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        #expect(detectFileType(for: url) == .video)
    }

    @Test func movDetection() {
        let url = URL(fileURLWithPath: "/tmp/test.mov")
        #expect(detectFileType(for: url) == .video)
    }

    @Test func m4vDetection() {
        let url = URL(fileURLWithPath: "/tmp/test.m4v")
        #expect(detectFileType(for: url) == .video)
    }

    @Test func unsupportedFormat() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        #expect(detectFileType(for: url) == nil)
    }

    @Test func noExtension() {
        let url = URL(fileURLWithPath: "/tmp/wallpaper")
        #expect(detectFileType(for: url) == nil)
    }
}
