import AppKit
import Photos

/// Fetches random videos from the Photos library for shuffle mode.
@MainActor
final class PhotosService {

    /// Request Photos library read access. Returns true if authorized.
    nonisolated func requestAccess() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited { return true }
        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return newStatus == .authorized || newStatus == .limited
    }

    /// Fetch a random video URL from the entire Photos library.
    /// Returns nil if no videos exist or access is denied.
    nonisolated func randomVideoURL() async -> URL? {
        guard await requestAccess() else { return nil }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        let allVideos = PHAsset.fetchAssets(with: options)
        guard allVideos.count > 0 else { return nil }

        let randomIndex = Int.random(in: 0..<allVideos.count)
        let asset = allVideos.object(at: randomIndex)

        return await withCheckedContinuation { continuation in
            let reqOptions = PHVideoRequestOptions()
            reqOptions.isNetworkAccessAllowed = true
            reqOptions.deliveryMode = .highQualityFormat

            var didResume = false
            PHImageManager.default().requestAVAsset(forVideo: asset, options: reqOptions) { avAsset, _, _ in
                guard !didResume else { return }
                didResume = true
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
