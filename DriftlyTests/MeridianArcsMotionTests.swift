import CoreGraphics
import Testing
@testable import Driftly

struct MeridianArcsMotionTests {
    @Test func independentReachesOccasionallyMeetAndThenSeparate() {
        let time = 87.0 // A non-roaming contour's held meeting, rather than an approximate near miss.
        let meeting = MeridianArcsMotion.strand(index: 5, count: 14, time: time)
        func gap(_ strand: MeridianArcsMotion.Strand) -> Double {
            let a = strand.point(fraction: 0, center: .zero, radiusX: 500, radiusY: 300)
            let b = strand.point(fraction: 1, center: .zero, radiusX: 500, radiusY: 300)
            return hypot(a.x - b.x, a.y - b.y)
        }
        #expect(gap(meeting) < 0.000_001)
        #expect(gap(MeridianArcsMotion.strand(index: 5, count: 14, time: time - 8)) > 10)
        #expect(gap(MeridianArcsMotion.strand(index: 5, count: 14, time: time + 8)) > 10)
        let other = MeridianArcsMotion.strand(index: 6, count: 14, time: time)
        #expect(gap(other) > 10)
        #expect(abs(other.start - meeting.start) > 0.01)
    }

    @Test func oneAttachedTipCrossesWestAndReturnsBeforeTheFlourishSettles() {
        let middle = MeridianArcsMotion.strand(index: 13, count: 14, time: 27)
        #expect(middle.point(fraction: 1, center: .zero, radiusX: 500, radiusY: 300).x < -350)
        // Its lower end and back stay on their contour while the free upper end roams.
        #expect(middle.point(fraction: 0.5, center: .zero, radiusX: 500, radiusY: 300).x < -450)
        for index in 0..<13 {
            #expect(MeridianArcsMotion.strand(index: index, count: 14, time: 27).excursion == .zero)
        }
        let home = MeridianArcsMotion.strand(index: 13, count: 14, time: 42)
        #expect(home.point(fraction: 1, center: .zero, radiusX: 500, radiusY: 300).x > 450)
        #expect(home.flourish > 0.99)
        #expect(MeridianArcsMotion.strand(index: 13, count: 14, time: 55).flourish == 0)
    }

    @Test func gestureHandoffsAndCycleWrapsDoNotJump() {
        for count in [10, 14] {
            for time in [6.0, 12, 14, 22, 24, 25, 29, 30, 35, 36, 39, 40, 41, 42, 54, 59, 68, 96, 97, 136, 192, 204] {
                for index in 0..<count {
                    let before = MeridianArcsMotion.strand(index: index, count: count, time: time - 0.000_01)
                    let after = MeridianArcsMotion.strand(index: index, count: count, time: time + 0.000_01)
                    for fraction in [0.0, 0.5, 0.75, 0.9, 1] {
                        let a = before.point(fraction: fraction, center: CGPoint(x: 900, y: 700),
                                             radiusX: 650, radiusY: 400, viewportHeight: 1400)
                        let b = after.point(fraction: fraction, center: CGPoint(x: 900, y: 700),
                                            radiusX: 650, radiusY: 400, viewportHeight: 1400)
                        #expect(hypot(a.x - b.x, a.y - b.y) < 0.01)
                    }
                }
            }
        }
    }

    @Test func verticalBreathsRiseAndDipStayVisibleAndReturnToTheQuietForm() {
        let center = CGPoint(x: 600, y: 1000)
        for (index, time, direction) in [(11, 23.0, -1.0), (8, 40.0, 1.0)] {
            let motion = MeridianArcsMotion.strand(index: index, count: 14, time: time)
            let lifted = motion.point(fraction: motion.liftCenter, center: center,
                                      radiusX: 500, radiusY: 300, viewportHeight: 2000)
            let resting = motion.point(fraction: motion.liftCenter, center: center, radiusX: 500, radiusY: 300)
            #expect((lifted.y - resting.y) * direction > 250)
            // A vertical breath moves a section of the ribbon, never pulling its ends out of contact.
            for fraction in [0.0, 1.0] {
                #expect(motion.point(fraction: fraction, center: center, radiusX: 500, radiusY: 300,
                                     viewportHeight: 2000)
                        == motion.point(fraction: fraction, center: center, radiusX: 500, radiusY: 300))
            }
            #expect(MeridianArcsMotion.strand(index: index, count: 14, time: 64).lift == 0)
        }
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1032, height: 1376),
                     CGSize(width: 1376, height: 1032), CGSize(width: 1920, height: 1080)] {
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.55)
            for sample in 0...96 {
                let time = Double(sample) * 2
                var liftingCount = 0
                for index in 0..<14 {
                    let motion = MeridianArcsMotion.strand(index: index, count: 14, time: time)
                    if motion.lift != 0 { liftingCount += 1 }
                    let radiusX = min(min(size.width, size.height) * 0.60, size.width * 0.46)
                        * (0.22 + 0.38 * Double(index) / 13) / 0.60
                    let radiusY = radiusX * (0.55 + 0.10 * sin(time * 0.05 + Double(index) / 13 * 3))
                    for step in 0...20 {
                        let point = motion.point(fraction: Double(step) / 20, center: center,
                                                 radiusX: radiusX, radiusY: radiusY, viewportHeight: size.height)
                        #expect(point.x >= 5 && point.x <= size.width - 5)
                        #expect(point.y >= 5 && point.y <= size.height - 5)
                    }
                }
                #expect(liftingCount <= 2)
            }
        }
    }
}
