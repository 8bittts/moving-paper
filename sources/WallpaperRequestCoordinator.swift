import CoreGraphics
import Foundation

enum WallpaperAssignmentTarget: Hashable {
    case allDesktops
    case display(CGDirectDisplayID)
}

@MainActor
final class WallpaperRequestCoordinator {
    private var activeTokens: [WallpaperAssignmentTarget: UUID] = [:]
    private var activeTasks: [WallpaperAssignmentTarget: Task<Void, Never>] = [:]

    func start(
        for target: WallpaperAssignmentTarget,
        operation: @escaping @MainActor (_ token: UUID) async -> Void
    ) {
        cancel(target)

        let token = UUID()
        activeTokens[target] = token
        activeTasks[target] = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { finish(target, token: token) }
            await operation(token)
        }
    }

    func cancel(_ target: WallpaperAssignmentTarget) {
        activeTasks.removeValue(forKey: target)?.cancel()
        activeTokens.removeValue(forKey: target)
    }

    func cancelAll() {
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        activeTokens.removeAll()
    }

    func isCurrent(_ token: UUID, for target: WallpaperAssignmentTarget) -> Bool {
        activeTokens[target] == token && !Task.isCancelled
    }

    private func finish(_ target: WallpaperAssignmentTarget, token: UUID) {
        guard activeTokens[target] == token else { return }
        activeTasks.removeValue(forKey: target)
        activeTokens.removeValue(forKey: target)
    }
}
