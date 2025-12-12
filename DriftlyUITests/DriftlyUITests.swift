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

    @MainActor
    func testModePickerOpensAndSelectsMode() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["modePickerButton"].tap()

        let modeRow = app.buttons["modeRow-nebulaLake"]
        XCTAssertTrue(modeRow.waitForExistence(timeout: 3))
        modeRow.tap()
    }

    @MainActor
    func testSettingsSheetOpens() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["settingsButton"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSleepTimerCanBeSet() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["sleepTimerButton"].tap()
        app.buttons["15 minutes"].tap()
    }
}
