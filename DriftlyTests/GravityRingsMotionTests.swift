import CoreGraphics
import Testing
@testable import Driftly

struct GravityRingsMotionTests {
    @Test func reflectedTravelReachesBothWallsAndReversesContinuously() {
        let right = (1 - 0.82) * 32
        let left = (2 - 0.82) * 32
        for (time, wall) in [(right, 1.0), (left, 0.0)] {
            let at = GravityRingsMotion.axis(time: time, duration: 32, offset: 0.82)
            let before = GravityRingsMotion.axis(time: time - 0.02, duration: 32, offset: 0.82)
            let after = GravityRingsMotion.axis(time: time + 0.02, duration: 32, offset: 0.82)
            #expect(abs(at.position - wall) < 0.000_001)
            #expect(abs(before.position - after.position) < 0.000_001)
            #expect(wall == 1 ? before.position < at.position : before.position > at.position)
            #expect(at.contact > 0.999)
        }
    }

    @Test func impactSquashesAgainstWallThenSettlesWithoutRimJump() {
        let size = CGSize(width: 1376, height: 1032)
        let time = (1 - 0.82) * 32
        let impact = GravityRingsMotion.pose(size: size, time: time)
        let settled = GravityRingsMotion.pose(size: size, time: time + 4)
        #expect(impact.scaleX < 0.90)
        #expect(impact.scaleY > 1.03)
        #expect(abs(settled.scaleX - 1) < 0.001)
        for index in 0..<6 {
            for sample in 0..<24 {
                let angle = Double(sample) * .pi * 2 / 24
                func displacement(_ t: Double) -> Double {
                    GravityRingsMotion.rimDisplacement(angle: angle, index: index, time: t,
                                                       pose: GravityRingsMotion.pose(size: size, time: t))
                }
                #expect(abs(displacement(time - 0.000_001) - displacement(time + 0.000_001)) < 0.000_01)
            }
        }
    }

    @Test func deformedOuterRimAndGlowStayInsidePortraitAndLandscapeBounds() {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1376, height: 1032),
                     CGSize(width: 1032, height: 1376), CGSize(width: 1920, height: 1080)] {
            let radius = GravityRingsMotion.outerRadius(in: size)
            for frame in 0...480 {
                let time = Double(frame) * 0.5
                let pose = GravityRingsMotion.pose(size: size, time: time)
                for sample in 0..<32 {
                    let angle = Double(sample) * .pi * 2 / 32
                    let wave = GravityRingsMotion.rimDisplacement(angle: angle, index: 5, time: time, pose: pose)
                    let r = radius * CGFloat(1 + wave)
                    let x = pose.center.x + r * CGFloat(cos(angle)) * pose.scaleX
                    let y = pose.center.y + r * CGFloat(sin(angle)) * pose.scaleY
                    #expect(x > 8 && x < size.width - 8)
                    #expect(y > 8 && y < size.height - 8)
                }
            }
        }
    }
}
