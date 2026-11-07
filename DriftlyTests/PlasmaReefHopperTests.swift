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

    @Test func roamingRoutesVisitAllSidesWithoutClippingTheCreature() {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1032, height: 1376),
                     CGSize(width: 1376, height: 1032), CGSize(width: 1920, height: 1080)] {
            var minX = 1.0, maxX = 0.0, minY = 1.0, maxY = 0.0
            var routeCount = 0
            var clippedSamples = 0
            let margin = PlasmaReefHopper.creatureRadius(in: size) * 3.3 + 3
            for cycle in 0..<18 {
                let time = PlasmaReefHopper.initialPhase + Double(cycle) * PlasmaReefHopper.cycleDuration
                guard let route = PlasmaReefHopper.route(size: size, time: time) else { continue }
                routeCount += 1
                for sample in 0...56 {
                    let t = route.startTime + (route.endTime - route.startTime) * Double(sample) / 56
                    let foot = route.pose(size: size, time: t).foot
                    minX = min(minX, foot.x / size.width)
                    maxX = max(maxX, foot.x / size.width)
                    minY = min(minY, foot.y / size.height)
                    maxY = max(maxY, foot.y / size.height)
                    if foot.x < margin || foot.x > size.width - margin
                        || foot.y < margin || foot.y > size.height - margin { clippedSamples += 1 }
                }
            }
            #expect(routeCount >= 12, "Expected frequent visible routes at \(size)")
            #expect(clippedSamples == 0, "Creature needs room for its rotating body, tail and feelers at \(size)")
            #expect(minX < 0.20 && maxX > 0.80, "Horizontal coverage \(minX)...\(maxX) at \(size)")
            #expect(minY < 0.23 && maxY > 0.78, "Vertical coverage \(minY)...\(maxY) at \(size)")
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(Double(a.x - b.x), Double(a.y - b.y))
    }
}
