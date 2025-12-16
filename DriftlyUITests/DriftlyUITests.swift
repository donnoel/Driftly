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
        let app = launchApp(arguments: ["UITestingReset", "UITestingForceChromeVisible", "UITestingOpenModePicker"])

        // Snapshot Photon Rain
        selectMode(app, identifier: "modeRow-photonRain", expectedLabel: "Photon Rain")
        snapshotView(app, name: "PhotonRain")

        // Snapshot Voxel Mirage
        selectMode(app, identifier: "modeRow-voxelMirage", expectedLabel: "Voxel Mirage")
        snapshotView(app, name: "VoxelMirage")
    }

    @MainActor
    func testSnapshotInkTopography() throws {
        let app = launchApp(arguments: ["UITestingReset", "UITestingForceChromeVisible", "UITestingOpenModePicker"])
        selectMode(app, identifier: "modeRow-inkTopography", expectedLabel: "Ink Topography")
        snapshotView(app, name: "InkTopography")
    }

    // Helpers

    private func ensureModePickerOpen(_ app: XCUIApplication) {
        ensureChromeVisible(in: app)

        let navBar = app.navigationBars["Select Mode"]
        let sheetMarker = app.otherElements["modePickerSheet"]

        if navBar.waitForExistence(timeout: 6) || sheetMarker.waitForExistence(timeout: 6) {
            return
        }

        let modeButton = app.buttons["modePickerButton"].firstMatch
        XCTAssertTrue(modeButton.waitForExistence(timeout: 8), "Mode picker button not found")

        // Make sure it's hittable; if not, tap the canvas to reveal chrome again
        for _ in 0..<3 where !modeButton.isHittable {
            app.tap()
            if app.navigationBars["Select Mode"].waitForExistence(timeout: 2) { return }
        }

        let tapModePicker = {
            if modeButton.isHittable {
                modeButton.tap()
            } else {
                let coord = modeButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coord.tap()
            }
        }

        tapModePicker()

        let table = app.tables.firstMatch
        let primaryRow = app.buttons["modeRow-nebulaLake"].firstMatch

        // Retry a few times in case the first tap races with UI animation
        for _ in 0..<4 where !navBar.exists && !table.exists && !primaryRow.exists && !sheetMarker.exists {
            tapModePicker()
            _ = navBar.waitForExistence(timeout: 1.5)
            _ = sheetMarker.waitForExistence(timeout: 1.0)
        }

        // Final hard wait before failing; accept table/row presence as signal too
        let opened = navBar.waitForExistence(timeout: 4) ||
            sheetMarker.waitForExistence(timeout: 4) ||
            table.waitForExistence(timeout: 4) ||
            primaryRow.waitForExistence(timeout: 4)

        XCTAssertTrue(opened, "Mode picker did not open")
    }

    private func selectMode(_ app: XCUIApplication, identifier: String, expectedLabel: String) {
        ensureModePickerOpen(app)

        let table = app.tables.firstMatch
        _ = table.waitForExistence(timeout: 4)

        // Prefer identifier, fall back to label-containing cells/text/buttons
        let idRow = app.buttons[identifier].firstMatch
        let altIdRow = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        let labelRow = app.cells.containing(.staticText, identifier: expectedLabel).firstMatch
        let textRow = app.staticTexts[expectedLabel]

        var target = resolvedTarget(idRow: idRow, altIdRow: altIdRow, labelRow: labelRow, textRow: textRow)

        // Scroll to find/hit if needed
        if table.exists {
            for _ in 0..<24 where !target.exists || !target.isHittable {
                table.swipeUp()
                target = resolvedTarget(idRow: idRow, altIdRow: altIdRow, labelRow: labelRow, textRow: textRow)
            }
            if !target.exists || !target.isHittable {
                for _ in 0..<24 where !target.exists || !target.isHittable {
                    table.swipeDown()
                    target = resolvedTarget(idRow: idRow, altIdRow: altIdRow, labelRow: labelRow, textRow: textRow)
                }
            }
        } else {
            // As a fallback, swipe the whole app if no table is detected
            for _ in 0..<8 where !target.exists || !target.isHittable {
                app.swipeUp()
                target = resolvedTarget(idRow: idRow, altIdRow: altIdRow, labelRow: labelRow, textRow: textRow)
            }
        }

        if !target.exists {
            _ = textRow.waitForExistence(timeout: 6)
            target = resolvedTarget(idRow: idRow, altIdRow: altIdRow, labelRow: labelRow, textRow: textRow)
        }

        XCTAssertTrue(target.waitForExistence(timeout: 14), "Mode row \(identifier)/\(expectedLabel) not found")

        if target.isHittable {
            target.tap()
        } else {
            // Try one more scroll nudge then tap via coordinate if needed
            if table.exists { table.swipeDown() }
            _ = target.waitForExistence(timeout: 4)
            if target.isHittable {
                target.tap()
            } else {
                let coord = target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                coord.tap()
            }
        }

        if app.buttons["Done"].waitForExistence(timeout: 2) {
            app.buttons["Done"].tap()
        }

        // Make sure chrome is visible again before snapshotting
        ensureChromeVisible(in: app)
    }

    private func resolvedTarget(
        idRow: XCUIElement,
        altIdRow: XCUIElement,
        labelRow: XCUIElement,
        textRow: XCUIElement
    ) -> XCUIElement {
        if idRow.exists { return idRow }
        if altIdRow.exists { return altIdRow }
        if labelRow.exists { return labelRow }
        return textRow
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
