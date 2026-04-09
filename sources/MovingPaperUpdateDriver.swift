import AppKit
import SwiftUI
@preconcurrency import Sparkle

struct MovingPaperUpdatePresentationSnapshot: Equatable {
    let title: String
    let message: String
    let detail: String?
    let notes: String?
    let progress: Double?
    let isIndeterminate: Bool
    let buttons: [String]
}

struct MovingPaperUpdatePresentation {
    enum ActionRole {
        case primary
        case secondary
        case destructive
    }

    struct Action {
        let title: String
        let role: ActionRole
        let handler: () -> Void
    }

    let title: String
    let message: String
    let detail: String?
    let notes: String?
    let progress: Double?
    let isIndeterminate: Bool
    let actions: [Action]

    var snapshot: MovingPaperUpdatePresentationSnapshot {
        MovingPaperUpdatePresentationSnapshot(
            title: title,
            message: message,
            detail: detail,
            notes: notes,
            progress: progress,
            isIndeterminate: isIndeterminate,
            buttons: actions.map(\.title)
        )
    }
}

@MainActor
protocol MovingPaperUpdatePresenting {
    func present(_ presentation: MovingPaperUpdatePresentation)
    func dismiss()
    func focus()
}

private enum MovingPaperUpdatePalette {
    static let backgroundTop = Color(red: 0.11, green: 0.14, blue: 0.22)
    static let backgroundBottom = Color(red: 0.07, green: 0.09, blue: 0.16)
    static let card = Color.white.opacity(0.07)
    static let stroke = Color.white.opacity(0.12)
    static let primary = Color(red: 0.99, green: 0.52, blue: 0.12)
    static let secondary = Color.white.opacity(0.12)
    static let destructive = Color(red: 0.81, green: 0.29, blue: 0.26)
    static let text = Color.white
    static let subtext = Color.white.opacity(0.72)
    static let notesBackground = Color.black.opacity(0.18)
}

private struct MovingPaperUpdatePanelView: View {
    let icon: NSImage?
    let presentation: MovingPaperUpdatePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                iconView
                VStack(alignment: .leading, spacing: 8) {
                    Text(presentation.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(MovingPaperUpdatePalette.text)

                    Text(presentation.message)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(MovingPaperUpdatePalette.subtext)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = presentation.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(MovingPaperUpdatePalette.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let notes = presentation.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Release Notes")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(MovingPaperUpdatePalette.text)

                    ScrollView {
                        Text(notes)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(MovingPaperUpdatePalette.subtext)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 88, maxHeight: 148)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MovingPaperUpdatePalette.notesBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(MovingPaperUpdatePalette.stroke, lineWidth: 1)
                    )
                }
            }

            if presentation.isIndeterminate || presentation.progress != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if presentation.isIndeterminate {
                        ProgressView()
                            .controlSize(.large)
                            .tint(MovingPaperUpdatePalette.primary)
                    } else if let progress = presentation.progress {
                        ProgressView(value: progress)
                            .tint(MovingPaperUpdatePalette.primary)
                        Text("\(Int((progress * 100).rounded()))% complete")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(MovingPaperUpdatePalette.subtext)
                    }
                }
            }

            HStack(spacing: 10) {
                Spacer(minLength: 0)
                ForEach(Array(presentation.actions.indices), id: \.self) { index in
                    MovingPaperUpdateActionButton(action: presentation.actions[index])
                }
            }
        }
        .padding(22)
        .frame(width: 470)
        .background(background)
    }

    private var iconView: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 62, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MovingPaperUpdatePalette.stroke, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(MovingPaperUpdatePalette.card)
                    .frame(width: 62, height: 62)
            }
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        MovingPaperUpdatePalette.backgroundTop,
                        MovingPaperUpdatePalette.backgroundBottom,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(MovingPaperUpdatePalette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(MovingPaperUpdatePalette.stroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 22, y: 14)
    }

}

private struct MovingPaperUpdateActionButton: View {
    let action: MovingPaperUpdatePresentation.Action

    var body: some View {
        Group {
            if action.role == .primary {
                Button(action.title) {
                    action.handler()
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
            } else {
                Button(action.title) {
                    action.handler()
                }
                .buttonStyle(.bordered)
                .tint(tint)
            }
        }
        .controlSize(.large)
    }

    private var tint: Color {
        switch action.role {
        case .primary:
            return MovingPaperUpdatePalette.primary
        case .secondary:
            return MovingPaperUpdatePalette.secondary
        case .destructive:
            return MovingPaperUpdatePalette.destructive
        }
    }
}

@MainActor
final class MovingPaperUpdatePanelPresenter: NSObject, MovingPaperUpdatePresenting {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    func present(_ presentation: MovingPaperUpdatePresentation) {
        let content = AnyView(
            MovingPaperUpdatePanelView(icon: NSApp.applicationIconImage, presentation: presentation)
        )

        if let hostingView, let panel {
            hostingView.rootView = content
            resize(panel: panel, hostingView: hostingView)
            focus()
            return
        }

        let hostingView = NSHostingView(rootView: content)
        let initialSize = hostingView.fittingSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = NSView(frame: NSRect(origin: .zero, size: initialSize))

        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostingView)

        self.panel = panel
        self.hostingView = hostingView
        resize(panel: panel, hostingView: hostingView)
        focus()
    }

    func dismiss() {
        guard let panel else { return }
        panel.orderOut(nil)
        self.panel = nil
        self.hostingView = nil
    }

    func focus() {
        guard let panel else { return }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func resize(panel: NSPanel, hostingView: NSHostingView<AnyView>) {
        let size = hostingView.fittingSize
        panel.setContentSize(size)
        panel.center()
    }
}

enum MovingPaperUpdateStatusEvent {
    case available(version: String)
    case upToDate
    case aborted(message: String)
}

enum MovingPaperUpdateStageDescriptor {
    case notDownloaded
    case downloaded
    case installing
}

struct MovingPaperUpdateContext {
    let version: String
    let title: String?
    let detail: String?
    let notes: String?
    let informationOnly: Bool
    let critical: Bool
    let majorUpgrade: Bool
    let infoURL: URL?
    let stage: MovingPaperUpdateStageDescriptor

    init(
        version: String,
        title: String? = nil,
        detail: String? = nil,
        notes: String? = nil,
        informationOnly: Bool = false,
        critical: Bool = false,
        majorUpgrade: Bool = false,
        infoURL: URL? = nil,
        stage: MovingPaperUpdateStageDescriptor = .notDownloaded
    ) {
        self.version = version
        self.title = title
        self.detail = detail
        self.notes = notes
        self.informationOnly = informationOnly
        self.critical = critical
        self.majorUpgrade = majorUpgrade
        self.infoURL = infoURL
        self.stage = stage
    }

    init(item: SUAppcastItem, state: SPUUserUpdateState, releaseNotes: String?) {
        let version = item.displayVersionString.isEmpty ? item.versionString : item.displayVersionString
        let stage: MovingPaperUpdateStageDescriptor
        switch state.stage {
        case .downloaded:
            stage = .downloaded
        case .installing:
            stage = .installing
        default:
            stage = .notDownloaded
        }

        self.init(
            version: version,
            title: item.title,
            detail: Self.makeDetail(item: item),
            notes: releaseNotes ?? Self.releaseNotesText(from: item.itemDescription, format: item.itemDescriptionFormat),
            informationOnly: item.isInformationOnlyUpdate,
            critical: item.isCriticalUpdate,
            majorUpgrade: item.isMajorUpgrade,
            infoURL: item.infoURL,
            stage: stage
        )
    }

    private static func makeDetail(item: SUAppcastItem) -> String? {
        var fragments: [String] = []
        if let title = item.title, !title.isEmpty {
            fragments.append(title)
        }
        if item.isCriticalUpdate {
            fragments.append("Critical update")
        }
        if item.isMajorUpgrade {
            fragments.append("Major upgrade")
        }
        return fragments.isEmpty ? nil : fragments.joined(separator: " • ")
    }

    private static func releaseNotesText(from rawValue: String?, format: String?) -> String? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return MovingPaperUpdateDriver.plainTextReleaseNotes(rawValue, format: format)
    }
}

@MainActor
final class MovingPaperUpdateDriver: NSObject {
    var onStatusEvent: ((MovingPaperUpdateStatusEvent) -> Void)?

    private let presenter: any MovingPaperUpdatePresenting
    private var currentUpdate: MovingPaperUpdateContext?
    private var updateReply: ((SPUUserUpdateChoice) -> Void)?
    private var releaseNotesText: String?
    private var downloadCancellation: (() -> Void)?
    private var expectedContentLength: UInt64 = 0
    private var receivedContentLength: UInt64 = 0

    init(presenter: any MovingPaperUpdatePresenting = MovingPaperUpdatePanelPresenter()) {
        self.presenter = presenter
        super.init()
    }

    func presentUpdateFound(_ context: MovingPaperUpdateContext, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        currentUpdate = context
        updateReply = reply
        releaseNotesText = context.notes

        presenter.present(
            MovingPaperUpdatePresentation(
                title: title(for: context),
                message: message(for: context),
                detail: context.detail,
                notes: releaseNotesText,
                progress: nil,
                isIndeterminate: false,
                actions: updateActions(for: context, reply: reply)
            )
        )
    }

    func applyReleaseNotesText(_ notes: String) {
        guard let currentUpdate, let updateReply else { return }
        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedNotes.isEmpty else { return }
        releaseNotesText = normalizedNotes

        presentUpdateFound(
            MovingPaperUpdateContext(
                version: currentUpdate.version,
                title: currentUpdate.title,
                detail: currentUpdate.detail,
                notes: normalizedNotes,
                informationOnly: currentUpdate.informationOnly,
                critical: currentUpdate.critical,
                majorUpgrade: currentUpdate.majorUpgrade,
                infoURL: currentUpdate.infoURL,
                stage: currentUpdate.stage
            ),
            reply: updateReply
        )
    }

    private func title(for context: MovingPaperUpdateContext) -> String {
        if context.informationOnly {
            return "Update Available"
        }

        switch context.stage {
        case .downloaded:
            return "Ready to Install"
        case .installing:
            return "Finishing Update"
        case .notDownloaded:
            return context.critical ? "Critical Update Available" : "New Version Available"
        }
    }

    private func message(for context: MovingPaperUpdateContext) -> String {
        if context.informationOnly {
            return "MovingPaper \(context.version) is available on the release page."
        }

        switch context.stage {
        case .downloaded:
            return "MovingPaper \(context.version) has finished downloading and is ready to install."
        case .installing:
            return "MovingPaper \(context.version) is already being installed."
        case .notDownloaded:
            return "MovingPaper \(context.version) is available to download and install."
        }
    }

    private func updateActions(
        for context: MovingPaperUpdateContext,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) -> [MovingPaperUpdatePresentation.Action] {
        if context.informationOnly, let infoURL = context.infoURL {
            return [
                MovingPaperUpdatePresentation.Action(title: "Dismiss", role: .secondary) { [weak self] in
                    self?.clearSessionState()
                    self?.presenter.dismiss()
                    reply(.dismiss)
                },
                MovingPaperUpdatePresentation.Action(title: "Open Release Page", role: .primary) { [weak self] in
                    NSWorkspace.shared.open(infoURL)
                    self?.clearSessionState()
                    self?.presenter.dismiss()
                    reply(.dismiss)
                },
            ]
        }

        if context.informationOnly {
            return [
                MovingPaperUpdatePresentation.Action(title: "Skip This Version", role: .destructive) { [weak self] in
                    self?.clearSessionState()
                    self?.presenter.dismiss()
                    reply(.skip)
                },
                MovingPaperUpdatePresentation.Action(title: "Dismiss", role: .secondary) { [weak self] in
                    self?.clearSessionState()
                    self?.presenter.dismiss()
                    reply(.dismiss)
                },
            ]
        }

        let installTitle: String
        switch context.stage {
        case .downloaded:
            installTitle = "Install and Relaunch"
        case .installing:
            installTitle = "Install Now"
        case .notDownloaded:
            installTitle = "Install Update"
        }

        return [
            MovingPaperUpdatePresentation.Action(title: "Skip This Version", role: .destructive) { [weak self] in
                self?.clearSessionState()
                self?.presenter.dismiss()
                reply(.skip)
            },
            MovingPaperUpdatePresentation.Action(title: "Later", role: .secondary) { [weak self] in
                self?.clearSessionState()
                self?.presenter.dismiss()
                reply(.dismiss)
            },
            MovingPaperUpdatePresentation.Action(title: installTitle, role: .primary) {
                reply(.install)
            },
        ]
    }

    private func resetProgress() {
        downloadCancellation = nil
        expectedContentLength = 0
        receivedContentLength = 0
    }

    private func clearSessionState() {
        currentUpdate = nil
        updateReply = nil
        releaseNotesText = nil
        resetProgress()
    }

    private func currentVersionLabel() -> String {
        guard let currentUpdate else { return "the new version" }
        return "MovingPaper \(currentUpdate.version)"
    }

    private func progressValue() -> Double? {
        guard expectedContentLength > 0 else { return nil }
        let ratio = Double(receivedContentLength) / Double(expectedContentLength)
        return min(max(ratio, 0), 1)
    }

    private func downloadActions() -> [MovingPaperUpdatePresentation.Action] {
        guard let downloadCancellation else { return [] }
        return [
            MovingPaperUpdatePresentation.Action(title: "Cancel Download", role: .secondary) { [weak self] in
                self?.clearSessionState()
                self?.presenter.dismiss()
                downloadCancellation()
            },
        ]
    }

    nonisolated private static func stringEncoding(for name: String?) -> String.Encoding {
        guard let name, !name.isEmpty else { return .utf8 }
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return .utf8 }
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return String.Encoding(rawValue: nsEncoding)
    }

    nonisolated static func plainTextReleaseNotes(_ rawValue: String, format: String?) -> String {
        let normalizedFormat = format?.lowercased()
        if normalizedFormat == "html" {
            let data = Data(rawValue.utf8)
            if let text = plainTextHTML(data: data, encoding: .utf8) {
                return text
            }
        }
        return rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func plainTextHTML(data: Data, encoding: String.Encoding) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: encoding.rawValue,
        ]
        guard let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        let string = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return string.isEmpty ? nil : string
    }
}

// MARK: - SPUUserDriver

@MainActor
extension MovingPaperUpdateDriver: @preconcurrency SPUUserDriver {
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        clearSessionState()
        let detail = request.systemProfile.isEmpty
            ? "MovingPaper can check for updates automatically and keep your menu bar app current."
            : "MovingPaper can check for updates automatically. System profile sharing remains off in this custom flow."

        presenter.present(
            MovingPaperUpdatePresentation(
                title: "Automatic Updates",
                message: "Allow MovingPaper to check for updates automatically?",
                detail: detail,
                notes: nil,
                progress: nil,
                isIndeterminate: false,
                actions: [
                    MovingPaperUpdatePresentation.Action(title: "Not Now", role: .secondary) { [weak self] in
                        self?.clearSessionState()
                        self?.presenter.dismiss()
                        reply(SUUpdatePermissionResponse(
                            automaticUpdateChecks: false,
                            automaticUpdateDownloading: nil,
                            sendSystemProfile: false
                        ))
                    },
                    MovingPaperUpdatePresentation.Action(title: "Check Automatically", role: .primary) { [weak self] in
                        self?.clearSessionState()
                        self?.presenter.dismiss()
                        reply(SUUpdatePermissionResponse(
                            automaticUpdateChecks: true,
                            automaticUpdateDownloading: nil,
                            sendSystemProfile: false
                        ))
                    },
                ]
            )
        )
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        clearSessionState()
        presenter.present(
            MovingPaperUpdatePresentation(
                title: "Checking for Updates",
                message: "Looking for the newest MovingPaper release.",
                detail: nil,
                notes: nil,
                progress: nil,
                isIndeterminate: true,
                actions: [
                    MovingPaperUpdatePresentation.Action(title: "Cancel", role: .secondary) { [weak self] in
                        self?.clearSessionState()
                        self?.presenter.dismiss()
                        cancellation()
                    },
                ]
            )
        )
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        let context = MovingPaperUpdateContext(item: appcastItem, state: state, releaseNotes: releaseNotesText)
        presentUpdateFound(context, reply: reply)
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        let encoding = Self.stringEncoding(for: downloadData.textEncodingName)
        let notes: String?
        if downloadData.mimeType?.contains("html") == true {
            notes = Self.plainTextHTML(data: downloadData.data as Data, encoding: encoding)
        } else {
            notes = String(data: downloadData.data as Data, encoding: encoding)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let notes, !notes.isEmpty else { return }
        applyReleaseNotesText(notes)
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
        let nsError = error as NSError
        guard let currentUpdate else { return }
        let fallbackNotes = [currentUpdate.notes, "Release notes could not be loaded: \(nsError.localizedDescription)"]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        applyReleaseNotesText(fallbackNotes)
    }

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        let nsError = error as NSError
        clearSessionState()
        presenter.present(
            MovingPaperUpdatePresentation(
                title: "You're Up To Date",
                message: "MovingPaper is already on the newest version available.",
                detail: nsError.localizedRecoverySuggestion,
                notes: nil,
                progress: nil,
                isIndeterminate: false,
                actions: [
                    MovingPaperUpdatePresentation.Action(title: "OK", role: .primary) { [weak self] in
                        self?.clearSessionState()
                        self?.presenter.dismiss()
                        acknowledgement()
                    },
                ]
            )
        )
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        let nsError = error as NSError
        clearSessionState()
        presenter.present(
            MovingPaperUpdatePresentation(
                title: "Update Failed",
                message: nsError.localizedDescription,
                detail: nsError.localizedRecoverySuggestion ?? nsError.localizedFailureReason,
                notes: nil,
                progress: nil,
                isIndeterminate: false,
                actions: [
                    MovingPaperUpdatePresentation.Action(title: "OK", role: .primary) { [weak self] in
                        self?.presenter.dismiss()
                        acknowledgement()
                    },
                ]
            )
        )
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        resetProgress()
        downloadCancellation = cancellation
        presenter.present(
            MovingPaperUpdatePresentation(
                title: "Downloading Update",
                message: "Downloading \(currentVersionLabel()).",
                detail: nil,
                notes: nil,
                progress: nil,
                isIndeterminate: true,
                actions: downloadActions()
            )
        )
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        self.expectedContentLength = expectedContentLength
        presenter.present(
            MovingPaperUpdatePresentation(
                title: "Downloading Update",
                message: "Downloading \(currentVersionLabel()).",
                detail: nil,
                notes: nil,
                progress: progressValue(),
                isIndeterminate: false,
                actions: downloadActions()
            )
        )
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        receivedContentLength += length
        presenter.present(
            MovingPaperUpdatePresentation(
                title: "Downloading Update",
                message: "Downloading \(currentVersionLabel()).",
                detail: nil,
                notes: nil,
                progress: progressValue(),
                isIndeterminate: expectedContentLength == 0,
                actions: downloadActions()
            )
        )
    }

    func showDownloadDidStartExtractingUpdate() {
        downloadCancellation = nil
        presenter.present(
            MovingPaperUpdatePresentation(
                title: "Preparing Update",
                message: "Extracting and verifying \(currentVersionLabel()).",
                detail: nil,
                notes: nil,
                progress: nil,
                isIndeterminate: true,
                actions: []
            )
        )
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        presenter.present(
            MovingPaperUpdatePresentation(
                title: "Preparing Update",
                message: "Extracting and verifying \(currentVersionLabel()).",
                detail: nil,
                notes: nil,
                progress: min(max(progress, 0), 1),
                isIndeterminate: false,
                actions: []
            )
        )
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        presenter.present(
            MovingPaperUpdatePresentation(
                title: "Ready to Install",
                message: "\(currentVersionLabel()) is ready to install and relaunch.",
                detail: nil,
                notes: nil,
                progress: nil,
                isIndeterminate: false,
                actions: [
                    MovingPaperUpdatePresentation.Action(title: "Cancel This Update", role: .destructive) { [weak self] in
                        self?.clearSessionState()
                        self?.presenter.dismiss()
                        reply(.skip)
                    },
                    MovingPaperUpdatePresentation.Action(title: "Later", role: .secondary) { [weak self] in
                        self?.clearSessionState()
                        self?.presenter.dismiss()
                        reply(.dismiss)
                    },
                    MovingPaperUpdatePresentation.Action(title: "Install and Relaunch", role: .primary) {
                        reply(.install)
                    },
                ]
            )
        )
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        var detail: String?
        var actions: [MovingPaperUpdatePresentation.Action] = []

        if applicationTerminated {
            detail = "MovingPaper is closed. The installer is finishing the update."
        } else {
            detail = "MovingPaper still needs to terminate before installation can finish."
            actions = [
                MovingPaperUpdatePresentation.Action(title: "Retry Quit", role: .primary) {
                    retryTerminatingApplication()
                },
            ]
        }

        presenter.present(
            MovingPaperUpdatePresentation(
                title: "Installing Update",
                message: "Installing \(currentVersionLabel()).",
                detail: detail,
                notes: nil,
                progress: nil,
                isIndeterminate: true,
                actions: actions
            )
        )
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        clearSessionState()
        presenter.present(
            MovingPaperUpdatePresentation(
                title: "Update Installed",
                message: relaunched
                    ? "MovingPaper has been updated and relaunched."
                    : "MovingPaper has been updated.",
                detail: nil,
                notes: nil,
                progress: nil,
                isIndeterminate: false,
                actions: [
                    MovingPaperUpdatePresentation.Action(title: "OK", role: .primary) { [weak self] in
                        self?.clearSessionState()
                        self?.presenter.dismiss()
                        acknowledgement()
                    },
                ]
            )
        )
    }

    func dismissUpdateInstallation() {
        presenter.dismiss()
        clearSessionState()
    }

    func showUpdateInFocus() {
        presenter.focus()
    }
}

// MARK: - SPUUpdaterDelegate

@MainActor
extension MovingPaperUpdateDriver: @preconcurrency SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString.isEmpty ? item.versionString : item.displayVersionString
        onStatusEvent?(.available(version: version))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        onStatusEvent?(.upToDate)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        onStatusEvent?(.aborted(message: (error as NSError).localizedDescription))
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        NSApp.invalidateRestorableState()
        for window in NSApp.windows {
            window.invalidateRestorableState()
        }
    }
}
