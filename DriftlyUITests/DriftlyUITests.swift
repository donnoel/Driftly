//
//  DriftlyUITests.swift
//  DriftlyUITests
//
//  Created by Don Noel on 12/11/25.
//

import XCTest

final class DriftlyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: arguments)
        app.launch()
        return app
    }

    private func ensureChromeVisible(in app: XCUIApplication) {
        let chromeButton = app.buttons["modePickerButton"]
        if chromeButton.exists { return }

        for _ in 0..<3 {
            app.tap() // toggle chrome on
            if chromeButton.waitForExistence(timeout: 2) { return }
        }
    }

    @MainActor
    func testModePickerOpensAndSelectsMode() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "UITestingReset",
            "UITestingOpenModePicker"
        ])
        app.launch()

        ensureChromeVisible(in: app)

        let modeRow = app.buttons["modeRow-nebulaLake"].firstMatch
        XCTAssertTrue(modeRow.waitForExistence(timeout: 10))
        modeRow.tap()
    }

    @MainActor
    func testSettingsSheetOpens() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["UITestingReset"])
        app.launch()

        app.buttons["settingsButton"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSleepTimerCanBeSet() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "UITestingReset",
            "UITestingOpenSleepTimer"
        ])
        app.launch()

        ensureChromeVisible(in: app)

        let fifteen = app.buttons.matching(identifier: "15 minutes").firstMatch
        XCTAssertTrue(fifteen.waitForExistence(timeout: 10))
        fifteen.tap()
    }

    @MainActor
    func testModeLabelUpdatesAfterSelection() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "UITestingReset",
            "UITestingOpenModePicker"
        ])
        app.launch()

        let starlit = app.buttons["modeRow-starlitMist"].firstMatch
        XCTAssertTrue(starlit.waitForExistence(timeout: 10))
        starlit.tap()

        let label = app.staticTexts["Starlit Mist"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsSpeedLabelChanges() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: ["UITestingReset"])
        app.launch()

        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let lively = app.staticTexts["Lively"]
        let gentle = app.staticTexts["Gentle"]

        let slider = app.sliders.firstMatch
        if slider.waitForExistence(timeout: 5) {
            slider.adjust(toNormalizedSliderPosition: 0.0)
            XCTAssertTrue(gentle.waitForExistence(timeout: 3))

            slider.adjust(toNormalizedSliderPosition: 1.0)
            XCTAssertTrue(lively.waitForExistence(timeout: 3))
        } else {
            XCTFail("Animation speed slider not found")
        }
    }

    // MARK: - Snapshots

    @MainActor
    func testSnapshotPhotonRainAndVoxelMirage() throws {
        let app = launchApp(arguments: ["UITestingReset", "UITestingForceChromeVisible"])

        // Snapshot Photon Rain
        selectMode(app, identifier: "modeRow-photonRain", expectedLabel: "Photon Rain")
        snapshotView(app, name: "PhotonRain")

        // Snapshot Voxel Mirage
        selectMode(app, identifier: "modeRow-voxelMirage", expectedLabel: "Voxel Mirage")
        snapshotView(app, name: "VoxelMirage")
    }

    // Helpers

    private func selectMode(_ app: XCUIApplication, identifier: String, expectedLabel: String) {
        app.buttons["modePickerButton"].tap()
        let modeRow = app.buttons[identifier].firstMatch
        XCTAssertTrue(modeRow.waitForExistence(timeout: 5))
        modeRow.tap()
        XCTAssertTrue(app.staticTexts[expectedLabel].waitForExistence(timeout: 3))
    }

    private func snapshotView(_ app: XCUIApplication, name: String) {
        // Wait a moment for the frame to render
        sleep(1)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
