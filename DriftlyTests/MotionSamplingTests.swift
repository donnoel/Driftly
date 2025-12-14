@testable import Driftly
import XCTest

final class MotionSamplingTests: XCTestCase {

    func testDefaultInterval() {
        let interval = DriftMotionManager.samplingInterval(
            brightness: 1.0,
            isChromeVisible: true,
            isLowPowerModeEnabled: false
        )
        XCTAssertEqual(interval, 1.0 / 30.0, accuracy: 0.0001)
    }

    func testLowBrightnessSlowsSampling() {
        let interval = DriftMotionManager.samplingInterval(
            brightness: 0.2,
            isChromeVisible: true,
            isLowPowerModeEnabled: false
        )
        XCTAssertEqual(interval, 1.0 / 18.0, accuracy: 0.0001)
    }

    func testHiddenChromeSlowsSampling() {
        let interval = DriftMotionManager.samplingInterval(
            brightness: 1.0,
            isChromeVisible: false,
            isLowPowerModeEnabled: false
        )
        XCTAssertEqual(interval, 1.0 / 18.0, accuracy: 0.0001)
    }

    func testLowPowerModeUsesSlowestInterval() {
        let interval = DriftMotionManager.samplingInterval(
            brightness: 0.2,
            isChromeVisible: false,
            isLowPowerModeEnabled: true
        )
        XCTAssertEqual(interval, 1.0 / 15.0, accuracy: 0.0001)
    }
}
