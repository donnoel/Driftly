import SwiftUI

struct GravityRingsView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused || reduceMotion) { date in
            // The shared timeline already supplies continuous, pausable scene time.
            let seconds = date.timeIntervalSinceReferenceDate * max(0.25, speed)
            let t = seconds * 0.18

            GeometryReader { proxy in
                let size = proxy.size

                ZStack {
                    // Soft backdrop with restrained depth for long viewing sessions.
                    LinearGradient(
                        colors: [
                            config.palette.backgroundTop.opacity(0.93),
                            config.palette.backgroundBottom.opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .overlay(
                        RadialGradient(
                            colors: [
                                config.palette.primary.opacity(0.11),
                                config.palette.secondary.opacity(0.07),
                                Color.clear
                            ],
                            center: UnitPoint(
                                x: 0.52 + 0.06 * sin(t * 0.04),
                                y: 0.48 + 0.06 * cos(t * 0.035)
                            ),
                            startRadius: 0,
                            endRadius: max(size.width, size.height) * 0.90
                        )
                        .accessibilityHidden(true)
                        .blendMode(.screen)
                    )
                    .ignoresSafeArea()

                    // A buoyant group of elastic rings travels between all four walls.
                    Canvas { context, _ in
                        var ctx = context
                        renderRings(in: &ctx, size: size, t: t, seconds: seconds)
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }

    // MARK: - Ring Renderer

    private func renderRings(in context: inout GraphicsContext, size: CGSize, t: Double, seconds: Double) {
        let ringCount = 6
        let outerRadius = GravityRingsMotion.outerRadius(in: size)
        let pose = GravityRingsMotion.pose(size: size, time: seconds)
        var rings = context
        rings.translateBy(x: pose.center.x, y: pose.center.y)
        rings.scaleBy(x: pose.scaleX, y: pose.scaleY)

        for index in 0..<ringCount {
            let phase = Double(index) * 0.9
            let n = CGFloat(index) / CGFloat(ringCount - 1)
            let pulse = 0.5 + 0.5 * sin(t * 0.62 + phase)
            let pulse2 = 0.5 + 0.5 * cos(t * 0.40 + phase * 1.3)
            let radius = outerRadius * (0.22 + 0.78 * n)
                * (1 - 0.025 * (1 - n) * CGFloat(0.5 + 0.5 * sin(t * 0.08)))
            let center = CGPoint(x: CGFloat(4 * sin(t * 0.17 + phase)) * (1 - n),
                                 y: CGFloat(4 * cos(t * 0.15 + phase)) * (1 - n))
            let path = elasticRingPath(center: center, radius: radius, index: index,
                                       time: seconds, pose: pose)
            let lw = 1.25 + CGFloat(1.05 * pulse)
            let c1 = config.palette.secondary.opacity(0.17 + 0.07 * pulse)
            let c2 = config.palette.tertiary.opacity(0.14 + 0.06 * pulse2)
            let c3 = config.palette.primary.opacity(0.12 + 0.05 * pulse)

            if index == 0 {
                let glowRadius = radius * CGFloat(0.42 + 0.04 * sin(t * 0.95))
                rings.fill(Path(ellipseIn: CGRect(x: center.x - glowRadius, y: center.y - glowRadius,
                                                 width: glowRadius * 2, height: glowRadius * 2)),
                           with: .radialGradient(
                            Gradient(colors: [config.palette.tertiary.opacity(0.23),
                                              config.palette.tertiary.opacity(0.10), .clear]),
                            center: center, startRadius: 0, endRadius: glowRadius))
            }
            rings.stroke(path, with: .color(c1.opacity(0.07)), lineWidth: lw * 5)
            rings.stroke(path, with: .color(c2.opacity(0.09)), lineWidth: lw * 2.4)
            rings.stroke(path, with: .color(c1), lineWidth: lw)
            rings.stroke(path, with: .color(c3.opacity(0.65)), lineWidth: max(0.8, lw * 0.55))
            rings.stroke(path, with: .color(Color.white.opacity(0.05)), lineWidth: 0.75)
        }
    }

    private func elasticRingPath(center: CGPoint, radius: CGFloat, index: Int,
                                 time: Double, pose: GravityRingsMotion.Pose) -> Path {
        let steps = 160
        var path = Path()
        for step in 0..<steps {
            let angle = Double(step) * .pi * 2 / Double(steps)
            let displacement = GravityRingsMotion.rimDisplacement(angle: angle, index: index,
                                                                  time: time, pose: pose)
            let r = radius * CGFloat(1 + displacement)
            let point = CGPoint(x: center.x + r * CGFloat(cos(angle)),
                                y: center.y + r * CGFloat(sin(angle)))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// Pure reflected motion keeps collisions deterministic and independent of frame cadence.
enum GravityRingsMotion {
    struct Axis {
        let position: Double
        let contact: Double
        let sinceImpact: Double
        let wall: Double
    }

    struct Pose {
        let center: CGPoint
        let scaleX: CGFloat
        let scaleY: CGFloat
        let horizontal: Axis
        let vertical: Axis
    }

    static func outerRadius(in size: CGSize) -> CGFloat {
        max(12, min(size.width, size.height) * 0.32 - 10)
    }

    static func pose(size: CGSize, time: Double) -> Pose {
        let horizontal = axis(time: time, duration: 32, offset: 0.82)
        let vertical = axis(time: time, duration: 26, offset: 0.37)
        let scaleX = CGFloat(1 - 0.12 * horizontal.contact + 0.045 * vertical.contact)
        let scaleY = CGFloat(1 - 0.12 * vertical.contact + 0.045 * horizontal.contact)
        // Includes every rim wave and glow. Bounds follow the squash so contact stays near the wall.
        let envelope = outerRadius(in: size) * 1.10
        let marginX = min(size.width * 0.5, envelope * scaleX + 10)
        let marginY = min(size.height * 0.5, envelope * scaleY + 10)
        return Pose(center: CGPoint(x: marginX + CGFloat(horizontal.position) * max(0, size.width - 2 * marginX),
                                    y: marginY + CGFloat(vertical.position) * max(0, size.height - 2 * marginY)),
                    scaleX: scaleX, scaleY: scaleY, horizontal: horizontal, vertical: vertical)
    }

    static func axis(time: Double, duration: Double, offset: Double) -> Axis {
        let phase = max(0, time) / duration + offset
        let leg = floor(phase)
        let fraction = phase - leg
        let forward = Int(leg) % 2 == 0
        let raw = forward ? fraction : 1 - fraction
        let corner = 1.3 / duration
        func ease(_ distance: Double) -> Double {
            distance * distance * (2 * corner - distance) / (corner * corner)
        }
        let position = raw < corner ? ease(raw) : (raw > 1 - corner ? 1 - ease(1 - raw) : raw)
        let nearestImpact = min(fraction, 1 - fraction) * duration
        return Axis(position: position, contact: exp(-pow(nearestImpact / 0.9, 2)),
                    sinceImpact: fraction * duration, wall: forward ? -1 : 1)
    }

    static func rimDisplacement(angle: Double, index: Int, time: Double, pose: Pose) -> Double {
        let phase = Double(index) * 0.9
        let ripple = 0.020 * sin(3 * angle + time * 0.34 + phase)
            + 0.012 * sin(5 * angle - time * 0.21 + phase * 0.7)
        let top = pow(max(0, -sin(angle)), 6)
        let warp = 0.020 * top * sin(time * 0.37 + phase)
        func response(_ axis: Axis, direction: Double) -> Double {
            // The outside ring reacts first; the settling wave reaches the inner rings a moment later.
            let age = axis.sinceImpact - Double(5 - index) * 0.10
            guard age >= 0 else { return 0 }
            let envelope = (1 - exp(-age * 8)) * exp(-age / 2.6)
            let focus = 0.55 + 0.45 * cos(angle - direction)
            return 0.014 * envelope * focus * sin(4 * angle - age * 4.4)
        }
        let xWave = response(pose.horizontal, direction: pose.horizontal.wall > 0 ? 0 : .pi)
        let yWave = response(pose.vertical, direction: pose.vertical.wall > 0 ? .pi / 2 : -.pi / 2)
        return ripple + warp + xWave + yWave
    }
}
