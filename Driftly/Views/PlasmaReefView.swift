import SwiftUI

struct PlasmaReefView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hopperRoute: PlasmaReefHopper.Route?

    private func render(in context: inout GraphicsContext, size: CGSize, t: Double) {
        // Background gradient
        let bgRect = CGRect(origin: .zero, size: size)
        let bg = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height)
        )
        context.fill(Path(bgRect), with: bg)

        // Soft color wash (a milky layer to unify)
        let washCenter = CGPoint(
            x: size.width * (0.55 + 0.10 * sin(t * 0.04)),
            y: size.height * (0.45 + 0.12 * cos(t * 0.03))
        )
        let wash = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                config.palette.tertiary.opacity(0.10),
                config.palette.secondary.opacity(0.06),
                Color.clear
            ]),
            center: washCenter,
            startRadius: 0,
            endRadius: max(size.width, size.height) * 0.75
        )
        context.fill(Path(bgRect), with: wash)

        // MARK: - Geometric Reef Slabs (skewed, layered, drifting)
        let slabCount = PlasmaReefHopper.slabCount
        for i in 0..<slabCount {
            let geometry = PlasmaReefHopper.slab(index: i, size: size, time: t)
            let slab = Path(roundedRect: geometry.rect, cornerRadius: geometry.rect.height * 0.65)
                .applying(geometry.transform)

            let col: Color
            switch i % 3 {
            case 0: col = config.palette.primary
            case 1: col = config.palette.secondary
            default: col = config.palette.tertiary
            }

            // Layered strokes to make it feel like neon glass
            context.stroke(slab, with: .color(col.opacity(0.09)), lineWidth: 6)
            context.stroke(slab, with: .color(col.opacity(0.14)), lineWidth: 2.2)
            context.stroke(slab, with: .color(Color.white.opacity(0.06)), lineWidth: 0.9)
        }

        // MARK: - Micro "coral" ticks (tiny angled marks)
        let tickCount = 180
        let invW = 1.0 / Double(max(size.width, 1))
        let invH = 1.0 / Double(max(size.height, 1))
        for i in 0..<tickCount {
            let u = Double(i) * 0.37
            let x = size.width * CGFloat(DriftNoise.fract(0.17 * u + 0.02 * t))
            let y = size.height * CGFloat(DriftNoise.fract(0.11 * u + 0.015 * t + 0.3))

            let nx = Double(x) * invW
            let ny = Double(y) * invH
            let len = CGFloat(6 + 12 * DriftNoise.fbm(x: nx, y: ny, seed: 99, octaves: 3))

            // Avoid ambiguous trig overloads
            let ang = Double(0.6 * sin(t * 0.07 + u))
            let ca = CGFloat(cos(ang))
            let sa = CGFloat(sin(ang))

            var pth = Path()
            pth.move(to: CGPoint(x: x, y: y))
            pth.addLine(to: CGPoint(x: x + ca * len, y: y + sa * len))

            let c = (i % 2 == 0) ? config.palette.primary : config.palette.secondary
            context.stroke(pth, with: .color(c.opacity(0.06)), lineWidth: 1.0)
        }

        // MARK: - Scanline Glow (very subtle)
        let lines = 34
        for i in 0..<lines {
            let p = Double(i) / Double(lines - 1)
            let y = size.height * CGFloat(p)
            let wob = CGFloat(10 * sin(t * 0.05 + p * 8.0))

            var line = Path()
            line.move(to: CGPoint(x: 0, y: y + wob))
            line.addLine(to: CGPoint(x: size.width, y: y - wob))

            let c: Color
            switch i % 3 {
            case 0: c = config.palette.tertiary
            case 1: c = config.palette.secondary
            default: c = config.palette.primary
            }
            context.stroke(line, with: .color(c.opacity(0.018)), lineWidth: 1.0)
        }

    }

    private func drawHopper(in context: GraphicsContext, size: CGSize, time: Double, route: PlasmaReefHopper.Route) {
        let elapsed = time - route.startTime
        guard elapsed >= 0, time <= route.endTime else { return }
        let fade = min(1, min(elapsed / 1.2, (route.endTime - time) / 1.6))
        let alpha = fade * fade * (3 - 2 * fade)
        let pose = route.pose(size: size, time: time)
        let radius = min(12, max(5, min(size.width, size.height) * 0.018))
        if let landing = route.hops.last(where: { $0.arrival <= time }) {
            drawLandingStars(in: context, foot: pose.foot, radius: radius,
                             age: time - landing.arrival, opacity: alpha)
        }
        var creature = context
        creature.opacity = alpha
        creature.translateBy(x: pose.foot.x, y: pose.foot.y)
        creature.scaleBy(x: pose.facing, y: 1)
        if let index = route.hops.firstIndex(where: { time >= $0.departure && time < $0.arrival }) {
            let progress = (time - route.hops[index].departure) / PlasmaReefHopper.flightDuration
            let turn = index.isMultiple(of: 2)
                ? 0.28 * sin(progress * .pi * 2) * sin(progress * .pi)
                : .pi * 2 * progress * progress * (3 - 2 * progress)
            // Rotate around her body only; the ballistic path and landing contacts stay intact.
            creature.translateBy(x: 0, y: -radius)
            creature.rotate(by: .radians(turn))
            creature.translateBy(x: 0, y: radius)
        }

        let glowRect = CGRect(x: -radius * 3, y: -radius * 4, width: radius * 6, height: radius * 6)
        creature.fill(Path(ellipseIn: glowRect), with: .radialGradient(
            Gradient(colors: [config.palette.tertiary.opacity(0.18), Color.clear]),
            center: CGPoint(x: 0, y: -radius), startRadius: 0, endRadius: radius * 3
        ))

        // A tiny sea-spring: tucked feet, two feelers, and a trailing ribbon give the glow a personality.
        let bodyWidth = radius * (1.10 + pose.compression * 0.55)
        let bodyHeight = radius * (1.35 - pose.compression * 0.55)
        let body = CGRect(x: -bodyWidth, y: -bodyHeight * 1.65, width: bodyWidth * 2, height: bodyHeight * 1.6)
        var tail = Path()
        tail.move(to: CGPoint(x: -radius * 0.55, y: -radius * 0.65))
        tail.addQuadCurve(to: CGPoint(x: -radius * 2.2, y: -radius * 0.80),
                          control: CGPoint(x: -radius * 1.6, y: -radius * (1.5 + 0.2 * sin(time * 2))))
        creature.stroke(tail, with: .color(config.palette.secondary.opacity(0.45)), style: StrokeStyle(lineWidth: radius * 0.24, lineCap: .round))
        creature.fill(Path(ellipseIn: body), with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.74), config.palette.tertiary.opacity(0.66), config.palette.secondary.opacity(0.45)]),
            startPoint: CGPoint(x: 0, y: body.minY), endPoint: .zero
        ))
        for side in [-1.0, 1.0] {
            let x = radius * CGFloat(side) * 0.5
            var feeler = Path()
            feeler.move(to: CGPoint(x: x, y: body.minY + radius * 0.3))
            feeler.addQuadCurve(to: CGPoint(x: x + radius * 0.3, y: body.minY - radius * 0.75),
                                control: CGPoint(x: x - radius * 0.25, y: body.minY - radius * 0.25))
            creature.stroke(feeler, with: .color(config.palette.tertiary.opacity(0.6)), style: StrokeStyle(lineWidth: radius * 0.19, lineCap: .round))
        }
        creature.fill(Path(ellipseIn: CGRect(x: radius * 0.35, y: body.minY + body.height * 0.38, width: radius * 0.28, height: radius * 0.34)), with: .color(config.palette.backgroundBottom.opacity(0.9)))
        var feet = Path()
        feet.move(to: CGPoint(x: -radius * 0.6, y: -radius * 0.3))
        feet.addLine(to: CGPoint(x: -radius * 0.85, y: 0))
        feet.move(to: CGPoint(x: radius * 0.5, y: -radius * 0.3))
        feet.addLine(to: CGPoint(x: radius * 0.85, y: 0))
        creature.stroke(feet, with: .color(config.palette.tertiary.opacity(0.6)), style: StrokeStyle(lineWidth: radius * 0.2, lineCap: .round))
    }

    private func drawLandingStars(in context: GraphicsContext, foot: CGPoint, radius: CGFloat, age: Double, opacity: Double) {
        let duration = 0.8
        guard age >= 0, age < duration else { return }
        let progress = age / duration
        let fade = opacity * sin(.pi * progress) * (1 - progress)
        for index in 0..<5 {
            let angle = -2.8 + Double(index) * 0.62
            let distance = radius * CGFloat(1.0 + progress * 3.2)
            let center = CGPoint(
                x: foot.x + CGFloat(cos(angle)) * distance,
                y: foot.y - radius * 0.4 + CGFloat(sin(angle)) * distance + radius * CGFloat(progress * progress)
            )
            let r = radius * CGFloat(0.22 + 0.06 * sin(Double(index)))
            var star = Path()
            star.move(to: CGPoint(x: center.x, y: center.y - r))
            star.addLine(to: CGPoint(x: center.x + r * 0.25, y: center.y - r * 0.25))
            star.addLine(to: CGPoint(x: center.x + r, y: center.y))
            star.addLine(to: CGPoint(x: center.x + r * 0.25, y: center.y + r * 0.25))
            star.addLine(to: CGPoint(x: center.x, y: center.y + r))
            star.addLine(to: CGPoint(x: center.x - r * 0.25, y: center.y + r * 0.25))
            star.addLine(to: CGPoint(x: center.x - r, y: center.y))
            star.addLine(to: CGPoint(x: center.x - r * 0.25, y: center.y - r * 0.25))
            star.closeSubpath()
            let color = index.isMultiple(of: 2) ? Color(red: 1, green: 0.91, blue: 0.73) : config.palette.tertiary
            context.fill(star, with: .color(color.opacity(0.8 * fade)))
        }
    }

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            // Start within the established current, rather than with every slab off the left edge.
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed) + PlasmaReefHopper.initialPhase

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    var ctx = context
                    render(in: &ctx, size: size, t: t)
                }
                .blendMode(.screen)
                .blur(radius: 1.3)
                .compositingGroup()
                .overlay {
                    // Keep the tiny face and feelers legible against the softly blurred reef.
                    Canvas { context, _ in
                        if !reduceMotion, let hopperRoute {
                            drawHopper(in: context, size: size, time: t, route: hopperRoute)
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                // Route selection is bounded and runs once per cycle/size, never in the draw pass.
                .task(id: PlasmaReefHopper.RouteKey(size: size, time: t, enabled: !reduceMotion)) {
                    hopperRoute = reduceMotion ? nil : PlasmaReefHopper.route(size: size, time: t)
                }
            }
        }
    }
}


/// Geometry shared by reef drawing and landing prediction so feet meet the moving, tilted surface.
enum PlasmaReefHopper {
    static let initialPhase = 84.0
    static let slabCount = 26
    static let cycleDuration = 14.0
    static let flightDuration = 1.25

    struct RouteKey: Hashable {
        let width: CGFloat
        let height: CGFloat
        let cycle: Int
        let enabled: Bool

        init(size: CGSize, time: Double, enabled: Bool) {
            width = size.width
            height = size.height
            cycle = Int(floor(time / cycleDuration))
            self.enabled = enabled
        }
    }

    struct Slab {
        let rect: CGRect
        let transform: CGAffineTransform
        let wrap: Int

        var contact: CGPoint { CGPoint(x: rect.midX, y: rect.minY).applying(transform) }
    }

    struct Hop {
        let source: Int
        let target: Int
        let departure: Double
        let launch: CGPoint
        let landing: CGPoint
        let gravity: Double

        var arrival: Double { departure + flightDuration }

        func position(at time: Double) -> CGPoint {
            let elapsed = min(flightDuration, max(0, time - departure))
            let vx = Double(landing.x - launch.x) / flightDuration
            let vy = Double(landing.y - launch.y) / flightDuration - 0.5 * gravity * flightDuration
            return CGPoint(x: Double(launch.x) + vx * elapsed,
                           y: Double(launch.y) + vy * elapsed + 0.5 * gravity * elapsed * elapsed)
        }
    }

    struct Pose {
        let foot: CGPoint
        let compression: CGFloat
        let facing: CGFloat
    }

    struct Route {
        let startTime: Double
        let endTime: Double
        let initialSlab: Int
        let hops: [Hop]

        func pose(size: CGSize, time: Double) -> Pose {
            var perch = initialSlab
            var lastArrival = startTime - 1
            var facing: CGFloat = 1
            for hop in hops {
                facing = hop.landing.x >= hop.launch.x ? 1 : -1
                if time < hop.departure {
                    let anticipation = max(0, 1 - (hop.departure - time) / 0.35)
                    let landing = max(0, 1 - (time - lastArrival) / 0.45)
                    return Pose(foot: slab(index: perch, size: size, time: time).contact,
                                compression: CGFloat(0.22 * sin(.pi * anticipation) + 0.18 * sin(.pi * landing)), facing: facing)
                }
                if time < hop.arrival {
                    let progress = (time - hop.departure) / flightDuration
                    return Pose(foot: hop.position(at: time), compression: CGFloat(-0.12 * sin(.pi * progress)), facing: facing)
                }
                perch = hop.target
                lastArrival = hop.arrival
            }
            let settling = max(0, 1 - (time - lastArrival) / 0.45)
            return Pose(foot: slab(index: perch, size: size, time: time).contact,
                        compression: CGFloat(0.18 * sin(.pi * settling)), facing: facing)
        }
    }

    static func slab(index: Int, size: CGSize, time: Double) -> Slab {
        let phase = Double(index) * 0.83
        let p = Double(index) / Double(slabCount - 1)
        let y = size.height * CGFloat(0.12 + 0.78 * p)
            + CGFloat(18 * sin(time * 0.08 + phase) + 10 * cos(time * 0.05 + phase * 1.2))
        let width = size.width * CGFloat(0.18 + 0.28 * (0.5 + 0.5 * sin(phase * 1.7)))
        let height = size.height * CGFloat(0.010 + 0.020 * (0.5 + 0.5 * cos(phase * 1.3)))
        let unwrapped = time * (14 + 10 * sin(phase)) / Double(max(1, size.width + width))
        let x = -width + CGFloat(unwrapped - floor(unwrapped)) * (size.width + width)
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let shear = CGFloat(0.35 * sin(time * 0.06 + phase))
        let tilt = CGFloat(0.22 * sin(time * 0.05 + phase * 0.7))
        let transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .rotated(by: tilt)
            .concatenating(CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0))
            .translatedBy(x: -rect.midX, y: -rect.midY)
        return Slab(rect: rect, transform: transform, wrap: Int(floor(unwrapped)))
    }

    static func safePerch(index: Int, size: CGSize, from start: Double, through end: Double) -> Bool {
        let first = slab(index: index, size: size, time: start)
        let last = slab(index: index, size: size, time: end)
        let margin = min(size.width, size.height) * 0.045
        return first.wrap == last.wrap && [first.contact, last.contact].allSatisfy {
            $0.x > margin && $0.x < size.width - margin && $0.y > margin && $0.y < size.height - margin
        }
    }

    static func route(size: CGSize, time: Double) -> Route? {
        guard size.width > 1, size.height > 1 else { return nil }
        let start = floor(time / cycleDuration) * cycleDuration
        let firstDeparture = start + 2
        let source = (0..<slabCount).filter {
            safePerch(index: $0, size: size, from: start, through: firstDeparture)
        }.min {
            let a = slab(index: $0, size: size, time: firstDeparture).contact
            let b = slab(index: $1, size: size, time: firstDeparture).contact
            return hypot(a.x - size.width * 0.48, a.y - size.height * 0.55)
                < hypot(b.x - size.width * 0.48, b.y - size.height * 0.55)
        }
        guard var current = source else { return nil }
        let initialSlab = current
        let base = min(size.width, size.height)
        var hops: [Hop] = []
        var endTime = firstDeparture
        for step in 0..<3 {
            let departure = firstDeparture + Double(step) * 2.95
            let arrival = departure + flightDuration
            let waitEnd = step == 2 ? start + cycleDuration : departure + 2.95
            let launch = slab(index: current, size: size, time: departure).contact
            let candidates = (0..<slabCount).filter { index in
                guard index != current,
                      safePerch(index: index, size: size, from: departure, through: waitEnd) else { return false }
                let landing = slab(index: index, size: size, time: arrival).contact
                let dy = abs(landing.y - launch.y)
                return abs(landing.x - launch.x) < base * 0.6 && dy > base * 0.045 && dy < base * 0.23
            }
            let target = candidates.min { a, b in
                func score(_ index: Int) -> CGFloat {
                    let point = slab(index: index, size: size, time: arrival).contact
                    let dy = point.y - launch.y
                    let directionPenalty: CGFloat = (step % 2 == 0 ? dy > 0 : dy < 0) ? base * 0.25 : 0
                    return abs(point.x - launch.x) * 0.7 + abs(abs(dy) - base * 0.12) + directionPenalty
                }
                return score(a) < score(b)
            }
            guard let target else { break }
            let landing = slab(index: target, size: size, time: arrival).contact
            hops.append(Hop(source: current, target: target, departure: departure, launch: launch, landing: landing, gravity: Double(base) * 0.95))
            current = target
            endTime = waitEnd
        }
        guard !hops.isEmpty else { return nil }
        return Route(startTime: start, endTime: endTime, initialSlab: initialSlab, hops: hops)
    }
}
