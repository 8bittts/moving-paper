import Foundation

/// Extracts video IDs from YouTube URL strings.
enum YouTubeURLParser {

    private static let allowedHosts = Set(["youtube.com", "www.youtube.com", "m.youtube.com"])
    private static let allowedSchemes = Set(["http", "https"])
    private static let shortHost = "youtu.be"
    private static let allowedIDCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")

    /// Extract the 11-character video ID from a YouTube URL string.
    static func videoID(from string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = normalizedURLCandidate(from: trimmed)

        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              allowedSchemes.contains(scheme),
              let host = components.host?.lowercased() else {
            return nil
        }

        if host == shortHost {
            return validVideoID(from: firstPathComponent(in: components.path))
        }

        guard allowedHosts.contains(host) else { return nil }

        switch components.path {
        case "/watch":
            return components.queryItems?
                .first { $0.name == "v" }
                .flatMap { validVideoID(from: $0.value) }
        case "/shorts", "/embed", "/v":
            return nil
        default:
            let parts = components.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            guard let route = parts.first, ["shorts", "embed", "v"].contains(route) else {
                return nil
            }
            return validVideoID(from: parts.dropFirst().first)
        }
    }

    private static func normalizedURLCandidate(from string: String) -> String {
        guard !string.isEmpty else { return string }
        if string.contains("://") { return string }
        return "https://\(string)"
    }

    private static func firstPathComponent(in path: String) -> String? {
        path.split(separator: "/", omittingEmptySubsequences: true).first.map(String.init)
    }

    private static func validVideoID(from value: String?) -> String? {
        guard let value, value.count == 11 else {
            return nil
        }
        guard value.unicodeScalars.allSatisfy({ allowedIDCharacters.contains($0) }) else {
            return nil
        }
        return value
    }

    /// Whether the string looks like a YouTube URL.
    static func isYouTubeURL(_ string: String) -> Bool {
        videoID(from: string) != nil
    }
}
