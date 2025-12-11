import SwiftUI

protocol MotionControlling: AnyObject {
    func startIfNeeded()
    func stopUpdates()
}

enum MotionPhaseHandler {
    static func updateMotion(for phase: ScenePhase, motionController: MotionControlling) {
        switch phase {
        case .active:
            motionController.startIfNeeded()
        default:
            motionController.stopUpdates()
        }
    }
}
