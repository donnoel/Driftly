import SwiftUI

/// The same leaf geometry drives the garden, landing prediction, and the visitor's resting feet.
enum NeonKelpGarden {
    struct LeafID: Hashable {
        let frond: Int
        let blade: Int
    }

    struct Leaf {
        let origin: CGPoint
        let angle: Double
        let length: CGFloat
        let width: CGFloat
        let phase: Double
        let side: Double

        func curl(time: Double) -> Double { side * (0.22 + 0.12 * sin(time * 0.18 + phase)) }

        func sample(_ u: Double, time: Double) -> (center: CGPoint, normal: CGPoint, edge: CGFloat) {
            let curl = curl(time: time)
            let x = length * u
            let y = length * (curl * u * u + 0.035 * sin(.pi * u) * sin(time * 0.23 + u * 4 + phase))
            let slope = 2 * curl * u
            let normal = CGPoint(x: -slope / sqrt(1 + slope * slope), y: 1 / sqrt(1 + slope * slope))
            let opening = 0.70 + 0.30 * (0.5 + 0.5 * sin(time * 0.14 + phase))
            let edge = width * (pow(max(0, sin(.pi * u)), 0.85) * opening
                                * (0.75 + 0.25 * u) * (1 + 0.09 * sin(u * .pi * 3 - time * 0.22 + phase)))
            return (CGPoint(x: x, y: y), normal, edge)
        }

        func perch(time: Double) -> CGPoint {
            let point = sample(0.63, time: time)
            // Choose the upward-facing edge of the membrane, including its current curl.
            let side = cos(angle) >= 0 ? -0.85 : 1.0
            let local = CGPoint(x: point.center.x + point.normal.x * point.edge * side,
                                y: point.center.y + point.normal.y * point.edge * side)
            return CGPoint(x: origin.x + local.x * cos(angle) - local.y * sin(angle),
                           y: origin.y + local.x * sin(angle) + local.y * cos(angle))
        }
    }

    static func count(in size: CGSize) -> Int { min(9, max(5, Int(size.width / max(1, size.height) * 6))) }

    static func spine(_ u: Double, index: Int, count: Int, size: CGSize, time: Double) -> CGPoint {
        let phase = Double(index) * 2.17
        let base = min(size.width, size.height)
        let height = 0.58 + 0.32 * (0.5 + 0.5 * sin(phase * 1.3 + 0.8))
        let lean = 0.12 * sin(phase * 0.8)
        let wave = sin(time * (0.105 + 0.006 * Double(index % 4)) - u * 2.8 + phase)
        return CGPoint(x: size.width * (Double(index) + 0.5) / Double(count)
                            + base * (lean * u + 0.12 * u * u * wave),
                       y: size.height * (1.06 - height * u)
                            + base * (0.018 * u * u * sin(time * 0.083 + phase + u * 3)))
    }

    static func leaf(_ id: LeafID, size: CGSize, time: Double, dip: Double = 0) -> Leaf {
        let count = count(in: size)
        let phase = Double(id.frond) * 2.17
        let u = 0.23 + Double(id.blade) * 0.135 + 0.018 * sin(phase + Double(id.blade))
        let origin = spine(u, index: id.frond, count: count, size: size, time: time)
        let before = spine(u - 0.006, index: id.frond, count: count, size: size, time: time)
        let after = spine(u + 0.006, index: id.frond, count: count, size: size, time: time)
        let side = (id.blade + id.frond).isMultiple(of: 2) ? 1.0 : -1.0
        let leafPhase = phase + Double(id.blade) * 1.31
        let angle = atan2(after.y - before.y, after.x - before.x)
            + side * (0.88 + 0.12 * sin(time * 0.16 + leafPhase))
        let length = min(size.width, size.height) * (0.24 - 0.09 * u) * (0.86 + 0.14 * sin(leafPhase))
            * (id.frond.isMultiple(of: 2) ? 0.82 : 1.0)
        return Leaf(origin: origin, angle: angle + (cos(angle) >= 0 ? dip : -dip),
                    length: length, width: length * (0.17 + 0.045 * sin(leafPhase + 0.8)),
                    phase: leafPhase, side: side)
    }
}

enum NeonKelpVisitor {
    static let visitInterval = 96.0
    static func radius(in size: CGSize) -> CGFloat { min(12, max(6, min(size.width, size.height) * 0.012)) }

    struct RouteKey: Hashable {
        let width: CGFloat
        let height: CGFloat
        let visit: Int
        let enabled: Bool
        init(size: CGSize, time: Double, enabled: Bool) {
            width = size.width
            height = size.height
            visit = Int(floor(time / visitInterval))
            self.enabled = enabled
        }
    }

    struct Hop {
        let source: NeonKelpGarden.LeafID?
        let target: NeonKelpGarden.LeafID?
        let departure: Double
        let duration: Double
        let launch: CGPoint
        let landing: CGPoint
        let gravity: Double
        var arrival: Double { departure + duration }

        func position(at time: Double) -> CGPoint {
            let elapsed = min(duration, max(0, time - departure))
            let vy = (landing.y - launch.y) / duration - 0.5 * gravity * duration
            return CGPoint(x: launch.x + (landing.x - launch.x) * elapsed / duration,
                           y: launch.y + vy * elapsed + 0.5 * gravity * elapsed * elapsed)
        }
    }

    struct Pose {
        let foot: CGPoint
        let facing: CGFloat
        let flight: Double?
    }

    struct Route {
        let hops: [Hop]
        let direction: CGFloat
        var startTime: Double { hops.first?.departure ?? 0 }
        var endTime: Double { hops.last?.arrival ?? 0 }

        func isVisible(at time: Double) -> Bool { time >= startTime && time < endTime }

        func dip(for id: NeonKelpGarden.LeafID, at time: Double) -> Double {
            guard let landing = hops.last(where: { $0.target == id && $0.arrival <= time }) else { return 0 }
            return NeonKelpVisitor.dip(age: time - landing.arrival)
        }

        func pose(size: CGSize, time: Double) -> Pose? {
            guard isVisible(at: time) else { return nil }
            for hop in hops {
                if time < hop.departure, let source = hop.source {
                    let leaf = NeonKelpGarden.leaf(source, size: size, time: time, dip: dip(for: source, at: time))
                    return Pose(foot: leaf.perch(time: time), facing: direction, flight: nil)
                }
                if time < hop.arrival {
                    return Pose(foot: hop.position(at: time), facing: direction,
                                flight: (time - hop.departure) / hop.duration)
                }
            }
            return nil
        }
    }

    static func dip(age: Double) -> Double {
        guard age >= 0, age < 5 else { return 0 }
        // Zero position and velocity at contact, then a soft downward bend and recovery.
        return 0.14 * pow(sin(.pi * age / 5), 2) * exp(-age * 0.55)
    }

    static func route(size: CGSize, time: Double) -> Route? {
        guard size.width > 1, size.height > 1 else { return nil }
        let visit = Int(floor(time / visitInterval))
        let start = Double(visit) * visitInterval + 2
        let direction: CGFloat = visit.isMultiple(of: 2) ? 1 : -1
        let base = min(size.width, size.height)
        let margin = radius(in: size) * 3.4 + 5
        let ids = (0..<NeonKelpGarden.count(in: size)).flatMap { frond in
            (0..<6).map { NeonKelpGarden.LeafID(frond: frond, blade: $0) }
        }
        func visible(_ point: CGPoint) -> Bool {
            point.x >= margin && point.x <= size.width - margin
                && point.y >= margin + base * 0.10 && point.y <= size.height - margin - base * 0.07
        }
        func point(_ id: NeonKelpGarden.LeafID, _ t: Double) -> CGPoint {
            NeonKelpGarden.leaf(id, size: size, time: t).perch(time: t)
        }
        let arrival = start + 2.2
        let first = ids.filter { visible(point($0, arrival)) }.min {
            func score(_ id: NeonKelpGarden.LeafID) -> CGFloat {
                let p = point(id, arrival)
                return abs(p.x / size.width - (direction > 0 ? 0.12 : 0.88)) * 2 + abs(p.y / size.height - 0.50)
            }
            return score($0) < score($1)
        }
        guard var current = first else { return nil }
        var landing = point(current, arrival)
        let offscreenX = direction > 0 ? -margin * 2 : size.width + margin * 2
        var hops = [Hop(source: nil, target: current, departure: start, duration: 2.2,
                        launch: CGPoint(x: offscreenX, y: landing.y + base * 0.04), landing: landing,
                        gravity: base * 0.28)]
        var visited = Set([current])
        for step in 0..<11 {
            let lastArrival = hops.last!.arrival
            let departure = lastArrival + 1.25
            let launch = NeonKelpGarden.leaf(current, size: size, time: departure,
                                            dip: dip(age: departure - lastArrival)).perch(time: departure)
            if direction > 0 ? launch.x > size.width * 0.84 : launch.x < size.width * 0.16 { break }
            let duration = 2.2
            let arrival = departure + duration
            let candidates = ids.filter { id in
                let p = point(id, arrival)
                guard !visited.contains(id), visible(p), (p.x - launch.x) * direction > size.width * 0.045,
                      abs(p.x - launch.x) < size.width * 0.36, abs(p.y - launch.y) < base * 0.32 else { return false }
                let hop = Hop(source: current, target: id, departure: departure, duration: duration,
                              launch: launch, landing: p, gravity: base * 0.32)
                let vy = (p.y - launch.y) / duration - 0.5 * hop.gravity * duration
                let apex = hop.position(at: departure + min(duration, max(0, -vy / hop.gravity)))
                return apex.y >= margin
            }
            let target = candidates.min {
                func score(_ id: NeonKelpGarden.LeafID) -> CGFloat {
                    let p = point(id, arrival)
                    let aimX = launch.x + direction * size.width / Double(NeonKelpGarden.count(in: size))
                    let aimY = size.height * (0.48 + 0.14 * sin(Double(step) * 0.8 + Double(visit)))
                    return abs(p.x - aimX) / size.width * 2 + abs(p.y - aimY) / size.height
                }
                return score($0) < score($1)
            }
            guard let target else { break }
            landing = point(target, arrival)
            hops.append(Hop(source: current, target: target, departure: departure, duration: duration,
                            launch: launch, landing: landing, gravity: base * 0.32))
            visited.insert(target)
            current = target
        }
        let lastArrival = hops.last!.arrival
        let departure = lastArrival + 1.5
        let launch = NeonKelpGarden.leaf(current, size: size, time: departure,
                                        dip: dip(age: departure - lastArrival)).perch(time: departure)
        hops.append(Hop(source: current, target: nil, departure: departure, duration: 2.5,
                        launch: launch, landing: CGPoint(x: direction > 0 ? size.width + margin * 2 : -margin * 2,
                                                       y: launch.y - base * 0.03), gravity: base * 0.22))
        return Route(hops: hops, direction: direction)
    }
}
