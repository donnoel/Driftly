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
            "UITestingNoChromeToggle",
            "UITestingForceChromeVisible",
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
        app.launchArguments.append(contentsOf: ["UITestingReset", "UITestingNoChromeToggle", "UITestingForceChromeVisible"])
        app.launch()

        app.buttons["settingsButton"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSleepTimerCanBeSet() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "UITestingReset",
            "UITestingNoChromeToggle",
            "UITestingForceChromeVisible",
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
            "UITestingNoChromeToggle",
            "UITestingForceChromeVisible",
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
        app.launchArguments.append(contentsOf: ["UITestingReset", "UITestingNoChromeToggle", "UITestingForceChromeVisible"])
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
}
