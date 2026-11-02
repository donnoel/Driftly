import XCTest

@MainActor
final class TVRemoteGuideUITests: XCTestCase {
    func testGuideNavigationCompletionAndSettingsReplay() {
        continueAfterFailure = false
        let app = XCUIApplication()
        // Argument-domain override leaves the simulator's other app data intact.
        app.launchArguments = ["-driftly.tvRemoteGuide.completedVersion", "0"]
        app.launch()
        let remote = XCUIRemote.shared
        let title = app.staticTexts["remoteGuideTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Bring up the controls.")
        record(app, name: "Remote guide 1")

        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Find your atmosphere."].waitForExistence(timeout: 5))
        record(app, name: "Remote guide 2")
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["Bring up the controls."].waitForExistence(timeout: 5))
        remote.press(.select)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Set the glow."].waitForExistence(timeout: 5))
        record(app, name: "Remote guide 3")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Let Driftly wind down."].waitForExistence(timeout: 5))
        record(app, name: "Remote guide 4")
        remote.press(.select)
        XCTAssertTrue(app.buttons["modePickerButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(title.exists)

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["modePickerButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(title.exists, "Completed onboarding must stay dismissed after relaunch")

        let settings = app.buttons["settingsButton"]
        for _ in 0..<5 {
            if settings.hasFocus { break }
            remote.press(.right)
        }
        XCTAssertTrue(settings.hasFocus)
        remote.press(.select)
        let replay = app.buttons["remoteGuideReplay"]
        for _ in 0..<18 {
            if replay.hasFocus { break }
            remote.press(.down)
        }
        // tvOS reports focus on the containing List row rather than this button.
        // Selecting the final row must open the guide, which proves reachability.
        remote.press(.select)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Bring up the controls.")
        let skip = app.buttons["remoteGuideSkip"]
        for _ in 0..<4 {
            if skip.hasFocus { break }
            remote.press(.up)
        }
        XCTAssertTrue(skip.hasFocus)
        remote.press(.select)
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        XCTAssertFalse(title.exists)
    }

    private func record(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
