import SwiftUI

/// One surface calculation drives both the ink contours and the climber's feet.
enum InkTopographySurface {
    static let bands = 18
    static func step(in size: CGSize) -> Double { max(6, min(10, size.width / 80)) }

    static func y(x: Double, band: Int, size: CGSize, time: Double, octaves: Int) -> Double {
        let step = step(in: size)
        let left = floor(x / step) * step
        let right = min(size.width, left + step)
        let mix = (x - left) / max(0.001, right - left)
        let first = height(x: left, band: band, size: size, time: time, octaves: octaves)
        if mix < 0.000_001 { return first }
        return first * (1 - mix)
            + height(x: right, band: band, size: size, time: time, octaves: octaves) * mix
    }

    private static func height(x: Double, band: Int, size: CGSize, time: Double, octaves: Int) -> Double {
        let nx = x / max(1, size.width)
        let fraction = Double(band) / Double(bands - 1)
        let amplitude = min(92, size.height * 0.11)
        let noise = DriftNoise.fbm(x: nx * 2.2 + time * 0.03, y: fraction * 2 + time * 0.02,
                                   seed: 42, octaves: octaves)
        let ripple = (band % 5 == 0 || band % 7 == 0)
            ? 10 * sin(nx * .pi * 6 + time * 0.55 + Double(band) * 0.7) : 0
        // Leave enough room above the first rung for ears, jump arcs, and the victory dance.
        let margin = InkTopographyClimber.radius(in: size) * 4 + amplitude * 0.5 + 12
        return margin + fraction * max(1, size.height - margin * 2) + (noise - 0.5) * amplitude + ripple
    }
}

enum InkTopographyClimber {
    enum Activity { case rest, hop, slip, dance, walk, drop }
    struct Perch {
        let band: Int
        let x: Double
    }
    struct Stage {
        let activity: Activity
        let source: Perch
        let target: Perch
        let start: Double
        let duration: Double
        var end: Double { start + duration }
    }
    struct Pose {
        let foot: CGPoint
        let facing: Double
        let activity: Activity
        let progress: Double
        let landingAge: Double
        let stage: Stage
    }
    static func radius(in size: CGSize) -> Double { min(12, max(6, min(size.width, size.height) * 0.012)) }

    static let stages: [Stage] = {
        var result: [Stage] = []
        var perch = Perch(band: 17, x: 0.46)
        var clock = 0.0
        var step = 0
        let stations = [0.61, 0.77, 0.58, 0.36, 0.23, 0.41, 0.64, 0.79, 0.59, 0.38, 0.22, 0.43]
        func add(_ activity: Activity, to target: Perch, duration: Double) {
            result.append(Stage(activity: activity, source: perch, target: target, start: clock, duration: duration))
            clock += duration
            perch = target
        }
        func climb(to band: Int) {
            while perch.band > band {
                add(.rest, to: perch, duration: 1.6 + Double(step % 3) * 0.25)
                add(.hop, to: Perch(band: perch.band - 1, x: stations[step % stations.count]), duration: 1.9)
                step += 1
            }
        }
        climb(to: 12)
        add(.rest, to: perch, duration: 2.2)
        add(.slip, to: Perch(band: 15, x: 0.34), duration: 2.8)
        climb(to: 6)
        add(.rest, to: perch, duration: 2.6)
        add(.slip, to: Perch(band: 10, x: 0.66), duration: 3.2)
        climb(to: 0)
        add(.dance, to: perch, duration: 6)
        add(.walk, to: Perch(band: 0, x: 0.72), duration: 8)
        add(.drop, to: Perch(band: 17, x: 0.46), duration: 5.8)
        add(.rest, to: perch, duration: 4)
        return result
    }()
    static var cycleDuration: Double { stages.last!.end }

    static func pose(size: CGSize, time: Double, octaves: Int) -> Pose {
        let cycle = floor(time / cycleDuration)
        let local = time - cycle * cycleDuration
        let index = stages.firstIndex { local < $0.end } ?? (stages.count - 1)
        let stage = stages[index]
        let progress = min(1, max(0, (local - stage.start) / stage.duration))
        let absoluteStart = cycle * cycleDuration + stage.start
        func point(_ perch: Perch, at t: Double) -> CGPoint {
            let x = perch.x * size.width
            return CGPoint(x: x, y: InkTopographySurface.y(x: x, band: perch.band, size: size, time: t, octaves: octaves))
        }
        let launch = point(stage.source, at: absoluteStart + (stage.activity == .drop ? 0.8 : 0))
        let landing = point(stage.target, at: absoluteStart + stage.duration)
        let foot: CGPoint
        switch stage.activity {
        case .rest, .dance:
            foot = point(stage.source, at: time)
        case .walk:
            let mix = progress * progress * (3 - 2 * progress)
            foot = point(Perch(band: stage.source.band, x: stage.source.x + (stage.target.x - stage.source.x) * mix), at: time)
        case .hop:
            let arc = max(12, abs(landing.y - launch.y) * 0.50 + min(size.width, size.height) * 0.014)
            foot = CGPoint(x: launch.x + (landing.x - launch.x) * progress,
                           y: launch.y + (landing.y - launch.y) * progress - 4 * arc * progress * (1 - progress))
        case .slip, .drop:
            // The top opens first; then a slow accelerating fall carries him through the contours.
            let fall = stage.activity == .drop ? max(0, (progress * stage.duration - 0.8) / (stage.duration - 0.8)) : progress
            let mix = fall * fall
            let start = stage.activity == .drop && fall == 0 ? point(stage.source, at: time) : launch
            foot = CGPoint(x: start.x + (landing.x - start.x) * mix, y: start.y + (landing.y - start.y) * mix)
        }
        let previous = index > 0 ? stages[index - 1] : stages.last!
        let age = (stage.activity == .rest || stage.activity == .dance)
            && (previous.activity == .hop || previous.activity == .slip || previous.activity == .drop)
            ? local - stage.start : 100
        return Pose(foot: foot, facing: stage.target.x >= stage.source.x ? 1 : -1,
                    activity: stage.activity, progress: progress, landingAge: age, stage: stage)
    }

    static func gap(band: Int, pose: Pose, size: CGSize, time: Double, octaves: Int) -> ClosedRange<Double>? {
        guard pose.activity == .drop, band < InkTopographySurface.bands - 1 else { return nil }
        let age = pose.progress * pose.stage.duration
        let opening = min(1, age / 0.8)
        let ease = opening * opening * (3 - 2 * opening)
        let y = InkTopographySurface.y(x: pose.foot.x, band: band, size: size, time: time, octaves: octaves)
        let distance = abs(y - pose.foot.y)
        let reach = max(45, size.height * 0.09)
        let proximity = max(0, 1 - distance / reach)
        let width = radius(in: size) * 2.7 * ease * proximity * proximity * (3 - 2 * proximity)
        guard width > 0.2 else { return nil }
        return (pose.foot.x - width)...(pose.foot.x + width)
    }
}

/// Small native artwork, deliberately quieter than the contour field around it.
enum InkTopographySprite {
    static func draw(in context: GraphicsContext, pose: InkTopographyClimber.Pose, size: CGSize, time: Double) {
        let r = InkTopographyClimber.radius(in: size)
        var sprite = context
        sprite.translateBy(x: pose.foot.x, y: pose.foot.y)
        let dance = pose.activity == .dance ? pow(sin(.pi * pose.progress), 2) : 0
        let fall = pose.activity == .drop || pose.activity == .slip
        let tilt = dance * 0.27 * sin(pose.progress * .pi * 6)
            + (fall ? 0.22 * sin(pose.progress * .pi * 2) : 0)
        sprite.rotate(by: .radians(tilt))
        let landing = pose.landingAge < 0.7 ? 0.16 * sin(.pi * pose.landingAge / 0.7) : 0
        sprite.scaleBy(x: 1 + landing, y: 1 - landing)
        let mint = Color(red: 0.45, green: 0.91, blue: 0.85)
        let peach = Color(red: 1, green: 0.64, blue: 0.65)
        let violet = Color(red: 0.72, green: 0.51, blue: 0.98)
        var tail = Path()
        tail.move(to: CGPoint(x: -r * 0.65, y: -r * 0.7))
        tail.addCurve(to: CGPoint(x: -r * 1.7, y: -r * (1.0 + 0.15 * sin(time * 0.8))),
                      control1: CGPoint(x: -r * 2.5, y: r * 0.1), control2: CGPoint(x: -r * 2.3, y: -r * 1.9))
        sprite.stroke(tail, with: .color(violet.opacity(0.85)), style: StrokeStyle(lineWidth: r * 0.2, lineCap: .round))
        for side in [-1.0, 1.0] {
            let wiggle = 0.12 * sin(time * 0.7 + side) + dance * 0.25 * sin(pose.progress * .pi * 6 + side)
            var ear = Path()
            ear.move(to: CGPoint(x: side * r * 0.35, y: -r * 1.5))
            ear.addCurve(to: CGPoint(x: side * r * (0.9 + wiggle), y: -r * 2.7),
                         control1: CGPoint(x: side * r * 0.1, y: -r * 3.1),
                         control2: CGPoint(x: side * r * 1.4, y: -r * 3.0))
            ear.addQuadCurve(to: CGPoint(x: side * r * 0.7, y: -r * 1.6),
                             control: CGPoint(x: side * r * 1.2, y: -r * 1.8))
            sprite.fill(ear, with: .linearGradient(Gradient(colors: [peach.opacity(0.9), violet.opacity(0.65)]),
                        startPoint: CGPoint(x: 0, y: -r * 3), endPoint: CGPoint(x: 0, y: -r)))
            let lift = dance * (0.6 + 0.35 * sin(pose.progress * .pi * 6 + side))
            var arm = Path()
            arm.move(to: CGPoint(x: side * r * 0.65, y: -r))
            arm.addQuadCurve(to: CGPoint(x: side * r * (1.3 + dance * 0.2), y: -r * (0.8 + lift)),
                             control: CGPoint(x: side * r * 1.1, y: -r * (0.3 + lift)))
            sprite.stroke(arm, with: .color(mint.opacity(0.9)), style: StrokeStyle(lineWidth: r * 0.22, lineCap: .round))
            let stride = pose.activity == .walk ? 0.15 * sin(pose.progress * .pi * 16 + side * .pi / 2) : 0
            sprite.fill(Path(ellipseIn: CGRect(x: r * (side * 0.42 - 0.26 + stride), y: -r * 0.14,
                                               width: r * 0.52, height: r * 0.27)), with: .color(peach.opacity(0.9)))
        }
        sprite.fill(Path(ellipseIn: CGRect(x: -r * 0.88, y: -r * 1.95, width: r * 1.76, height: r * 1.92)),
                    with: .linearGradient(Gradient(colors: [mint, Color(red: 0.61, green: 0.72, blue: 1), peach]),
                        startPoint: CGPoint(x: -r * 0.6, y: -r * 1.9), endPoint: CGPoint(x: r * 0.7, y: 0)))
        sprite.fill(Path(ellipseIn: CGRect(x: -r * 0.45, y: -r * 0.8, width: r * 0.9, height: r * 0.6)),
                    with: .color(Color(red: 1, green: 0.91, blue: 0.73).opacity(0.6)))
        for side in [-1.0, 1.0] {
            let x = side * r * 0.31 + pose.facing * r * 0.05
            sprite.fill(Path(ellipseIn: CGRect(x: x - r * 0.085, y: -r * 1.29, width: r * 0.17, height: r * 0.23)),
                        with: .color(Color(red: 0.12, green: 0.10, blue: 0.23)))
            sprite.fill(Path(ellipseIn: CGRect(x: x - r * 0.035, y: -r * 1.27, width: r * 0.06, height: r * 0.07)),
                        with: .color(.white.opacity(0.85)))
        }
        var smile = Path()
        smile.move(to: CGPoint(x: -r * 0.15, y: -r * 0.99))
        smile.addQuadCurve(to: CGPoint(x: r * 0.15, y: -r * 0.99), control: CGPoint(x: 0, y: -r * 0.84))
        sprite.stroke(smile, with: .color(violet.opacity(0.9)), style: StrokeStyle(lineWidth: max(0.7, r * 0.07), lineCap: .round))
        let sparkleAge = pose.activity == .dance ? pose.progress * 2 : pose.landingAge
        if sparkleAge < 1.8 {
            let progress = sparkleAge / 1.8
            for index in 0..<4 {
                let angle = Double(index) * .pi / 3 + .pi
                let reach = r * (0.8 + progress * 1.8)
                let p = CGPoint(x: pose.foot.x + cos(angle) * reach,
                                y: pose.foot.y - r * 1.3 + sin(angle) * reach - r * progress)
                let length = r * 0.19 * sin(.pi * progress)
                var star = Path()
                star.move(to: CGPoint(x: p.x - length, y: p.y)); star.addLine(to: CGPoint(x: p.x + length, y: p.y))
                star.move(to: CGPoint(x: p.x, y: p.y - length)); star.addLine(to: CGPoint(x: p.x, y: p.y + length))
                context.stroke(star, with: .color(Color(red: 1, green: 0.83, blue: 0.56).opacity(0.65 * sin(.pi * progress))),
                               style: StrokeStyle(lineWidth: max(0.6, r * 0.07), lineCap: .round))
            }
        }
    }
}
