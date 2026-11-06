import CoreGraphics
import Testing
@testable import Driftly

struct ChromaticSpineMotionTests {
    @Test func tendrilsTouchTheActualMovingCircleThenWithdrawContinuously() {
        let size = CGSize(width: 1376, height: 1032)
        for index in 0..<5 {
            let time = (.pi * 3 - Double(index) * 1.37) / 0.40
            func gesture(_ t: Double) -> ChromaticSpineMotion.Gesture {
                ChromaticSpineMotion.gesture(index: index,
                                             circle: ChromaticSpineMotion.circle(index: index % 3, size: size, time: t),
                                             size: size, time: t)
            }
            let circle = ChromaticSpineMotion.circle(index: index % 3, size: size, time: time)
            let point = circle.point(angle: time * 0.14 + Double(index) * 1.37, time: time)
            #expect(hypot(gesture(time).tip.x - point.x, gesture(time).tip.y - point.y) < 0.000_001)
            #expect(gesture(time).reach > 0.999_999)
            #expect(gesture(time - 3).reach < 0.5)
            #expect(gesture(time + 3).reach < 0.5)
            #expect(hypot(gesture(time - 0.000_001).tip.x - gesture(time + 0.000_001).tip.x,
                          gesture(time - 0.000_001).tip.y - gesture(time + 0.000_001).tip.y) < 0.001)
        }
    }

    @Test func tipsStayVisibleAndNeverPassThroughTheCircleDuringRetreat() {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1376, height: 1032),
                     CGSize(width: 1032, height: 1376), CGSize(width: 1920, height: 1080)] {
            for sample in 0...240 {
                let time = Double(sample) * 0.5
                for index in 0..<5 {
                    let circle = ChromaticSpineMotion.circle(index: index % 3, size: size, time: time)
                    let gesture = ChromaticSpineMotion.gesture(index: index, circle: circle, size: size, time: time)
                    let angle = time * 0.14 + Double(index) * 1.37
                    #expect(hypot(gesture.tip.x - circle.center.x, gesture.tip.y - circle.center.y)
                            >= circle.edgeRadius(angle: angle, time: time) - 0.000_001)
                    #expect(gesture.tip.x >= 9.999 && gesture.tip.x <= size.width - 9.999)
                    #expect(gesture.tip.y >= 9.999 && gesture.tip.y <= size.height - 9.999)
                }
            }
        }
    }
}
