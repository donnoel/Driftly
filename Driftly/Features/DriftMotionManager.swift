import Foundation
import CoreMotion
import SwiftUI
import Combine

final class DriftMotionManager: ObservableObject, MotionControlling {
    #if os(iOS)
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var isUpdating = false
    #endif

    @Published var xTilt: Double = 0
    @Published var yTilt: Double = 0

    init() {
        #if os(iOS)
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0 // ~30fps
        #endif
    }

    deinit {
        #if os(iOS)
        motionManager.stopDeviceMotionUpdates()
        #endif
    }

    #if os(iOS)
    func startIfNeeded() {
        guard !isUpdating, motionManager.isDeviceMotionAvailable else { return }

        isUpdating = true

        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical,
                                               to: queue) { [weak self] motion, _ in
            guard let self, let motion, self.isUpdating else { return }

            let roll = motion.attitude.roll    // left/right tilt
            let pitch = motion.attitude.pitch  // forward/back tilt

            // Clamp to a gentle range so things don’t swing wildly
            let maxAngle: Double = 0.35 // ~20 degrees
            let clampedRoll  = max(-maxAngle, min(maxAngle, roll))
            let clampedPitch = max(-maxAngle, min(maxAngle, pitch))

            DispatchQueue.main.async {
                self.xTilt = clampedRoll
                self.yTilt = clampedPitch
            }
        }
    }

    func stopUpdates() {
        guard isUpdating else { return }
        motionManager.stopDeviceMotionUpdates()
        isUpdating = false
    }
    #endif

    var parallaxOffset: CGSize {
        let maxOffset: CGFloat = 12 // max pixels in any direction

        // Map [-maxAngle, maxAngle] → [-maxOffset, maxOffset]
        let maxAngle: Double = 0.35
        let x = CGFloat(xTilt / maxAngle) * maxOffset
        let y = CGFloat(-yTilt / maxAngle) * maxOffset // invert so tilt "into" screen moves content up

        return CGSize(width: x, height: y)
    }
}
