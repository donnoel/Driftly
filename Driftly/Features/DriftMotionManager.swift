import Foundation
import CoreMotion
import SwiftUI
import Combine

@MainActor
final class DriftMotionManager: ObservableObject, MotionControlling {
    #if os(iOS)
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var isUpdating = false
    private var filteredRoll: Double = 0
    private var filteredPitch: Double = 0
    #endif

    @Published var xTilt: Double = 0
    @Published var yTilt: Double = 0
    @Published var motionUnavailable: Bool = false

    init() {
        #if os(iOS)
        guard motionManager.isDeviceMotionAvailable else {
            motionUnavailable = true
            return
        }

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
        guard !isUpdating else { return }
        guard motionManager.isDeviceMotionAvailable else {
            motionUnavailable = true
            return
        }

        isUpdating = true
        motionUnavailable = false

        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical,
                                               to: queue) { [weak self] motion, _ in
            guard let motion else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.isUpdating else { return }

                let roll = motion.attitude.roll    // left/right tilt
                let pitch = motion.attitude.pitch  // forward/back tilt

                // Clamp to a gentle range so things don’t swing wildly
                let maxAngle: Double = 0.35 // ~20 degrees
                let clampedRoll  = max(-maxAngle, min(maxAngle, roll))
                let clampedPitch = max(-maxAngle, min(maxAngle, pitch))

                // Simple low-pass filter to smooth jitter
                let smoothing: Double = 0.15
                filteredRoll += smoothing * (clampedRoll - filteredRoll)
                filteredPitch += smoothing * (clampedPitch - filteredPitch)

                self.xTilt = filteredRoll
                self.yTilt = filteredPitch
            }
        }
    }

    func stopUpdates() {
        guard isUpdating else { return }
        isUpdating = false
        motionManager.stopDeviceMotionUpdates()
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
