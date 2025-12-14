@testable import Driftly
import XCTest

final class DriftlyRootViewInitTests: XCTestCase {

    func testInitDefaults() {
        let view = DriftlyRootView()
        XCTAssertFalse(view.test_isModePickerPresented)
        XCTAssertFalse(view.test_isSleepTimerDialogPresented)
    }

    func testInitWithOverrides() {
        let view = DriftlyRootView(testOverrides: (modePicker: true, sleepDialog: true))
        XCTAssertTrue(view.test_isModePickerPresented)
        XCTAssertTrue(view.test_isSleepTimerDialogPresented)
    }
}
