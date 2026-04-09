import Testing
@preconcurrency import Sparkle
@testable import MovingPaper

@MainActor
private final class MockUpdatePresenter: MovingPaperUpdatePresenting {
    var snapshots: [MovingPaperUpdatePresentationSnapshot] = []
    var lastPresentation: MovingPaperUpdatePresentation?
    var dismissCount = 0
    var focusCount = 0

    func present(_ presentation: MovingPaperUpdatePresentation) {
        lastPresentation = presentation
        snapshots.append(presentation.snapshot)
    }

    func dismiss() {
        dismissCount += 1
    }

    func focus() {
        focusCount += 1
    }
}

struct MovingPaperUpdateDriverTests {

    @Test @MainActor func userInitiatedChecksStayCancelable() {
        let presenter = MockUpdatePresenter()
        let driver = MovingPaperUpdateDriver(presenter: presenter)
        var didCancel = false

        driver.showUserInitiatedUpdateCheck(cancellation: {
            didCancel = true
        })

        let snapshot = try! #require(presenter.snapshots.last)
        #expect(snapshot.title == "Checking for Updates")
        #expect(snapshot.isIndeterminate)
        #expect(snapshot.buttons == ["Cancel"])

        presenter.lastPresentation?.actions.first?.handler()

        #expect(didCancel)
        #expect(presenter.dismissCount == 1)
    }

    @Test @MainActor func releaseNotesRefreshKeepsInstallActionLive() {
        let presenter = MockUpdatePresenter()
        let driver = MovingPaperUpdateDriver(presenter: presenter)
        var choice: SPUUserUpdateChoice?

        driver.presentUpdateFound(
            MovingPaperUpdateContext(
                version: "0.021",
                title: "Spring update"
            )
        ) { reply in
            choice = reply
        }

        driver.applyReleaseNotesText("Improved update presentation.\nFixed stale panel state.")

        let snapshot = try! #require(presenter.snapshots.last)
        #expect(snapshot.notes == "Improved update presentation.\nFixed stale panel state.")
        #expect(snapshot.buttons == ["Skip This Version", "Later", "Install Update"])

        presenter.lastPresentation?.actions.last?.handler()

        #expect(choice == .install)
    }

    @Test @MainActor func downloadProgressTracksExpectedLengthAndRetainsCancel() {
        let presenter = MockUpdatePresenter()
        let driver = MovingPaperUpdateDriver(presenter: presenter)
        var didCancel = false

        driver.showDownloadInitiated(cancellation: {
            didCancel = true
        })
        driver.showDownloadDidReceiveExpectedContentLength(400)
        driver.showDownloadDidReceiveData(ofLength: 100)

        let snapshot = try! #require(presenter.snapshots.last)
        #expect(snapshot.title == "Downloading Update")
        #expect(snapshot.progress == 0.25)
        #expect(snapshot.buttons == ["Cancel Download"])

        presenter.lastPresentation?.actions.first?.handler()

        #expect(didCancel)
        #expect(presenter.dismissCount == 1)
    }

    @Test @MainActor func repeatedExpectedLengthUpdatesDoNotResetDownloadProgress() {
        let presenter = MockUpdatePresenter()
        let driver = MovingPaperUpdateDriver(presenter: presenter)

        driver.showDownloadInitiated(cancellation: {})
        driver.showDownloadDidReceiveExpectedContentLength(400)
        driver.showDownloadDidReceiveData(ofLength: 100)
        driver.showDownloadDidReceiveExpectedContentLength(500)

        let snapshot = try! #require(presenter.snapshots.last)
        #expect(snapshot.progress == 0.2)
    }

    @Test @MainActor func showUpdateInFocusUsesPresenterFocus() {
        let presenter = MockUpdatePresenter()
        let driver = MovingPaperUpdateDriver(presenter: presenter)

        driver.showUpdateInFocus()

        #expect(presenter.focusCount == 1)
    }

    @Test @MainActor func newManualCheckClearsStaleReleaseNotesBeforeNextUpdatePrompt() {
        let presenter = MockUpdatePresenter()
        let driver = MovingPaperUpdateDriver(presenter: presenter)

        driver.presentUpdateFound(
            MovingPaperUpdateContext(
                version: "0.021",
                notes: "Old notes"
            )
        ) { _ in }

        driver.showUserInitiatedUpdateCheck(cancellation: {})

        driver.presentUpdateFound(
            MovingPaperUpdateContext(
                version: "0.022"
            )
        ) { _ in }

        let snapshot = try! #require(presenter.snapshots.last)
        #expect(snapshot.title == "New Version Available")
        #expect(snapshot.notes == nil)
    }
}
