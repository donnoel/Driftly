import CoreGraphics
import Testing
@testable import Driftly

@MainActor
struct NeonKelpVisitorTests {
    @Test func visitsAlternateSidesAndLeaveTheGardenQuiet() throws {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1032, height: 1376),
                     CGSize(width: 1376, height: 1032), CGSize(width: 1920, height: 1080)] {
            for visit in 0..<6 {
                let time = Double(visit) * NeonKelpVisitor.visitInterval
                let route = try #require(NeonKelpVisitor.route(size: size, time: time))
                let first = try #require(route.hops.first)
                let last = try #require(route.hops.last)
                #expect(route.hops.count >= 4, "Expected a leaf-to-leaf journey at \(size), visit \(visit)")
                #expect(route.endTime - route.startTime < 45)
                #expect(route.pose(size: size, time: route.endTime + 20) == nil)
                #expect(time + NeonKelpVisitor.visitInterval + 2 - route.endTime > 50)
                if visit.isMultiple(of: 2) {
                    #expect(first.launch.x < 0 && last.landing.x > size.width)
                    #expect(last.launch.x > size.width * 0.70, "Rightward visitor left too soon at \(size), visit \(visit)")
                } else {
                    #expect(first.launch.x > size.width && last.landing.x < 0)
                    #expect(last.launch.x < size.width * 0.30, "Leftward visitor left too soon at \(size), visit \(visit)")
                }
            }
        }
    }

    @Test func feetMeetTheMovingLeafAndStayAttachedDuringItsDip() throws {
        let size = CGSize(width: 1376, height: 1032)
        let route = try #require(NeonKelpVisitor.route(size: size, time: 0))
        for hop in route.hops {
            if let target = hop.target {
                let surface = NeonKelpGarden.leaf(target, size: size, time: hop.arrival).perch(time: hop.arrival)
                #expect(distance(hop.position(at: hop.arrival), surface) < 0.000_001)
                let before = try #require(route.pose(size: size, time: hop.arrival - 0.000_001))
                let after = try #require(route.pose(size: size, time: hop.arrival + 0.000_001))
                #expect(distance(before.foot, after.foot) < 0.001)
                let time = hop.arrival + 0.6
                let dip = route.dip(for: target, at: time)
                #expect(dip > 0)
                let dipped = NeonKelpGarden.leaf(target, size: size, time: time, dip: dip).perch(time: time)
                #expect(distance(try #require(route.pose(size: size, time: time)).foot, dipped) < 0.000_001)
            }
            if hop.source != nil {
                let before = try #require(route.pose(size: size, time: hop.departure - 0.000_001))
                #expect(distance(before.foot, hop.launch) < 0.001)
            }
        }
        #expect(NeonKelpVisitor.dip(age: 0) == 0)
        #expect(NeonKelpVisitor.dip(age: 6) == 0)
    }

    @Test func interiorFlightsHaveHeadroomAndConstantGravity() throws {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1376, height: 1032),
                     CGSize(width: 1920, height: 1080)] {
            for visit in 0..<4 {
                let route = try #require(NeonKelpVisitor.route(size: size, time: Double(visit) * 96))
                let margin = NeonKelpVisitor.radius(in: size) * 3.4 + 5
                for (landing, next) in zip(route.hops, route.hops.dropFirst()) {
                    for sample in 0...8 {
                        let time = landing.arrival + (next.departure - landing.arrival) * Double(sample) / 8
                        let p = try #require(route.pose(size: size, time: time)).foot
                        #expect(p.x >= margin && p.x <= size.width - margin,
                                "Resting perch clipped horizontally at \(size), visit \(visit), time \(time)")
                        #expect(p.y >= margin && p.y <= size.height - margin)
                    }
                }
                for hop in route.hops where hop.source != nil && hop.target != nil {
                    for sample in 0...40 {
                        let p = hop.position(at: hop.departure + hop.duration * Double(sample) / 40)
                        #expect(p.x >= margin && p.x <= size.width - margin)
                        #expect(p.y >= margin && p.y <= size.height - margin)
                    }
                    let a = hop.position(at: hop.departure + 0.4)
                    let b = hop.position(at: hop.departure + 0.5)
                    let c = hop.position(at: hop.departure + 0.6)
                    #expect(abs(c.y - 2 * b.y + a.y - hop.gravity * 0.01) < 0.000_001)
                }
            }
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }
}
