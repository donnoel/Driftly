import CoreGraphics
import Testing
@testable import Driftly

@MainActor
struct PlasmaReefHopperTests {
    @Test func freshSceneHasAVisibleRouteAndSafeFinalPerch() throws {
        let size = CGSize(width: 393, height: 852)
        let route = try #require(PlasmaReefHopper.route(size: size, time: PlasmaReefHopper.initialPhase))
        #expect(!route.hops.isEmpty)
        let last = try #require(route.hops.last)
        #expect(PlasmaReefHopper.safePerch(index: last.target, size: size, from: last.arrival, through: route.endTime))
        for index in 0...24 {
            let time = last.arrival + (route.endTime - last.arrival) * Double(index) / 24
            let point = route.pose(size: size, time: time).foot
            #expect(point.x > 0 && point.x < size.width)
            #expect(point.y > 0 && point.y < size.height)
        }
    }

    @Test func jumpsMeetActualMovingSlabSurfacesAtBothEnds() throws {
        let size = CGSize(width: 393, height: 852)
        let route = try #require(PlasmaReefHopper.route(size: size, time: PlasmaReefHopper.initialPhase))
        for hop in route.hops {
            let launch = PlasmaReefHopper.slab(index: hop.source, size: size, time: hop.departure).contact
            let landing = PlasmaReefHopper.slab(index: hop.target, size: size, time: hop.arrival).contact
            #expect(distance(hop.position(at: hop.departure), launch) < 0.000_001)
            #expect(distance(hop.position(at: hop.arrival), landing) < 0.000_001)
            #expect(distance(route.pose(size: size, time: hop.arrival - 0.000_001).foot,
                             route.pose(size: size, time: hop.arrival).foot) < 0.001)
        }
    }

    @Test func ballisticMotionRisesThenFallsUnderConstantGravity() {
        let hop = PlasmaReefHopper.Hop(source: 0, target: 1, departure: 0,
                                      launch: .zero, landing: CGPoint(x: 80, y: 20), gravity: 300)
        let early = hop.position(at: 0.1)
        let middle = hop.position(at: 0.625)
        let late = hop.position(at: 1.15)
        #expect(early.y < 0)
        #expect(middle.y < early.y)
        #expect(late.y > middle.y)
        let a = hop.position(at: 0.4)
        let b = hop.position(at: 0.5)
        let c = hop.position(at: 0.6)
        #expect(abs(Double(c.y - 2 * b.y + a.y) - hop.gravity * 0.01) < 0.000_001)
    }

    @Test func wrapBoundaryCannotBecomeAValidPerch() {
        let size = CGSize(width: 393, height: 852)
        let slab = PlasmaReefHopper.slab(index: 0, size: size, time: 0)
        let wrapTime = Double(size.width + slab.rect.width) / 14
        let before = PlasmaReefHopper.slab(index: 0, size: size, time: wrapTime - 0.1)
        let after = PlasmaReefHopper.slab(index: 0, size: size, time: wrapTime + 0.1)
        #expect(before.wrap != after.wrap)
        #expect(!PlasmaReefHopper.safePerch(index: 0, size: size, from: wrapTime - 0.1, through: wrapTime + 0.1))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(Double(a.x - b.x), Double(a.y - b.y))
    }
}
