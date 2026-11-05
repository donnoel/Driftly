import SwiftUI

struct KoiCurrentView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused || reduceMotion) { date in
            let time = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    render(in: context, size: size, time: time)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func render(in context: GraphicsContext, size: CGSize, time: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ]),
                startPoint: CGPoint(x: size.width * 0.50, y: 0),
                endPoint: CGPoint(x: size.width * 0.50, y: size.height)
            )
        )

        drawWaterWash(in: context, rect: rect, size: size, time: time)

        var currentLayer = context
        currentLayer.blendMode = .plusLighter
        drawKoiStrokes(in: &currentLayer, size: size, time: time)
        drawSurfaceGlints(in: &currentLayer, size: size, time: time)

        drawDepthVignette(in: context, size: size)
    }

    /// Broad underwater color blooms replace the repeated horizontal current lines.
    private func drawWaterWash(in context: GraphicsContext, rect: CGRect, size: CGSize, time: Double) {
        for index in 0..<4 {
            let phase = Double(index) * 1.73
            let center = CGPoint(
                x: size.width * CGFloat(0.5 + 0.38 * sin(phase + time * 0.018)),
                y: size.height * CGFloat(0.5 + 0.34 * cos(phase * 1.2 + time * 0.014))
            )
            let color = waterColor(phase: time * 0.012 + phase)
            var wash = context
            wash.translateBy(x: center.x, y: center.y)
            wash.rotate(by: .radians(phase + 0.12 * sin(time * 0.025)))
            wash.scaleBy(x: size.width * 0.62, y: size.height * 0.45)
            wash.fill(
                Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.16), color.opacity(0.055), .clear]),
                    center: .zero, startRadius: 0, endRadius: 1
                )
            )
        }
    }

    private func waterColor(phase: Double) -> Color {
        Color(red: 0.12 + 0.08 * (0.5 + 0.5 * sin(phase)),
              green: 0.42 + 0.15 * (0.5 + 0.5 * sin(phase + 2)),
              blue: 0.57 + 0.20 * (0.5 + 0.5 * sin(phase + 4)))
    }

    private func drawKoiStrokes(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let base = min(size.width, size.height)
        for index in 0..<7 {
            let phase = Double(index) * .pi * 2 / 7
            let length = base * CGFloat(0.22 + 0.025 * sin(phase))
            let pose = roamingPose(index: index, size: size, length: length, time: time)
            let center = pose.center
            let heading = pose.heading
            let swim = time * 1.15 + phase * 2
            let tintPhase = time * 0.035 + phase
            let warm = 0.5 + 0.5 * sin(tintPhase)
            let tailColor = Color(red: 0.28 + 0.64 * warm,
                                  green: 0.68 - 0.26 * warm, blue: 0.88 - 0.46 * warm)
            let headColor = Color(red: 0.74 + 0.26 * warm,
                                  green: 0.93 - 0.10 * warm, blue: 0.91 - 0.38 * warm)
            var fish = context
            fish.translateBy(x: center.x, y: center.y)
            fish.rotate(by: .radians(heading))

            // A continuous tapered silhouette, with the strongest bend travelling down the tail.
            var upper: [CGPoint] = []
            var lower: [CGPoint] = []
            for step in 0...40 {
                let u = Double(step) / 40
                let point = spine(at: u, length: length, phase: swim)
                let tangent = spineTangent(at: u, length: length, phase: swim)
                let width = length * CGFloat(0.105 * pow(max(0, sin(.pi * u)), 0.65) * (0.55 + 0.60 * u))
                upper.append(CGPoint(x: point.x - tangent.y * width, y: point.y + tangent.x * width))
                lower.append(CGPoint(x: point.x + tangent.y * width, y: point.y - tangent.x * width))
            }
            let body = softContour(upper + lower.reversed())
            let tail = spine(at: 0, length: length, phase: swim)
            let tailSway = length * CGFloat(0.035 * sin(swim))
            var fan = Path()
            fan.move(to: spine(at: 0.12, length: length, phase: swim))
            fan.addCurve(to: CGPoint(x: tail.x - length * 0.15, y: tail.y - length * 0.11 + tailSway),
                         control1: CGPoint(x: tail.x - length * 0.05, y: tail.y - length * 0.02),
                         control2: CGPoint(x: tail.x - length * 0.09, y: tail.y - length * 0.12))
            fan.addQuadCurve(to: CGPoint(x: tail.x - length * 0.11, y: tail.y + length * 0.12 + tailSway),
                             control: CGPoint(x: tail.x - length * 0.04, y: tail.y + tailSway))
            fan.addQuadCurve(to: spine(at: 0.12, length: length, phase: swim),
                             control: CGPoint(x: tail.x - length * 0.02, y: tail.y + length * 0.06))
            fish.fill(fan, with: .linearGradient(
                Gradient(colors: [tailColor.opacity(0.04), tailColor.opacity(0.30)]),
                startPoint: CGPoint(x: tail.x - length * 0.15, y: tail.y), endPoint: tail
            ))

            // Thin translucent fins flex independently of the body without separate moving blobs.
            for side in [-1.0, 1.0] {
                let root = spine(at: 0.68, length: length, phase: swim)
                let reach = length * CGFloat(side * (0.17 + 0.025 * sin(swim + side)))
                var fin = Path()
                fin.move(to: CGPoint(x: root.x + length * 0.06, y: root.y))
                fin.addQuadCurve(to: CGPoint(x: root.x - length * 0.13, y: root.y + reach),
                                 control: CGPoint(x: root.x + length * 0.02, y: root.y + reach * 0.85))
                fin.addQuadCurve(to: CGPoint(x: root.x - length * 0.10, y: root.y),
                                 control: CGPoint(x: root.x - length * 0.08, y: root.y + reach * 0.4))
                fish.fill(fin, with: .linearGradient(
                    Gradient(colors: [headColor.opacity(0.19), tailColor.opacity(0.015)]),
                    startPoint: root, endPoint: CGPoint(x: root.x, y: root.y + reach)
                ))
            }
            fish.fill(body, with: .linearGradient(
                Gradient(colors: [tailColor.opacity(0.15), tailColor.opacity(0.44), headColor.opacity(0.62)]),
                startPoint: CGPoint(x: -length * 0.5, y: 0), endPoint: CGPoint(x: length * 0.5, y: 0)
            ))
            var ridge = Path()
            for step in 0...24 {
                let point = spine(at: 0.16 + 0.72 * Double(step) / 24, length: length, phase: swim)
                if step == 0 { ridge.move(to: point) } else { ridge.addLine(to: point) }
            }
            fish.stroke(ridge, with: .linearGradient(
                Gradient(colors: [.clear, headColor.opacity(0.22), .clear]),
                startPoint: tail, endPoint: CGPoint(x: length * 0.45, y: 0)
            ), style: StrokeStyle(lineWidth: max(0.7, length * 0.012), lineCap: .round))

            // Small pearl eyes sit inside the head; pupils stay dark under additive water shading.
            let head = spine(at: 0.87, length: length, phase: swim)
            let eyeRadius = max(0.9, length * 0.017)
            var eyes = fish
            eyes.blendMode = .normal
            for side in [-1.0, 1.0] {
                let eye = CGPoint(x: head.x, y: head.y + length * CGFloat(side * 0.041))
                eyes.fill(Path(ellipseIn: CGRect(x: eye.x - eyeRadius, y: eye.y - eyeRadius,
                                                width: eyeRadius * 2, height: eyeRadius * 2)),
                          with: .color(headColor.opacity(0.72)))
                let pupil = eyeRadius * 0.55
                eyes.fill(Path(ellipseIn: CGRect(x: eye.x - pupil + eyeRadius * 0.16, y: eye.y - pupil,
                                                width: pupil * 2, height: pupil * 2)),
                          with: .color(Color(red: 0.015, green: 0.055, blue: 0.07).opacity(0.9)))
            }
        }
    }

    /// Broad, crossing currents wander through the middle and edges, rather than orbiting one center.
    private func roamingPose(index: Int, size: CGSize, length: CGFloat, time: Double)
        -> (center: CGPoint, heading: Double) {
        let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
        let progress = time * direction / (22 + 1.3 * Double(index % 3)) + Double(index) * 1.31
        let leg = Int(floor(progress))
        let u = progress - floor(progress)
        let start = currentWaypoint(leg, fish: index, time: time)
        let end = currentWaypoint(leg + 1, fish: index, time: time)
        let startTangent = currentTangent(leg, fish: index, time: time)
        let endTangent = currentTangent(leg + 1, fish: index, time: time)
        let c1 = CGPoint(x: start.x + startTangent.x, y: start.y + startTangent.y)
        let c2 = CGPoint(x: end.x - endTangent.x, y: end.y - endTangent.y)
        let v = 1 - u
        let x = v * v * v * start.x + 3 * v * v * u * c1.x + 3 * v * u * u * c2.x + u * u * u * end.x
        let y = v * v * v * start.y + 3 * v * v * u * c1.y + 3 * v * u * u * c2.y + u * u * u * end.y
        // Convex, bounded curves leave enough room for the entire fish and its flexing tail.
        let margin = length * 0.68 + 4
        let width = max(0, size.width - margin * 2)
        let height = max(0, size.height - margin * 2)
        let center = CGPoint(x: size.width * 0.5 + (x - 0.5) * width,
                             y: size.height * 0.5 + (y - 0.5) * height)
        let dx = 3 * v * v * (c1.x - start.x) + 6 * v * u * (c2.x - c1.x) + 3 * u * u * (end.x - c2.x)
        let dy = 3 * v * v * (c1.y - start.y) + 6 * v * u * (c2.y - c1.y) + 3 * u * u * (end.y - c2.y)
        return (center, atan2(Double(dy * height) * direction, Double(dx * width) * direction))
    }

    private func currentWaypoint(_ index: Int, fish: Int, time: Double) -> CGPoint {
        let slot = ((index % 8) + 8) % 8
        let point: CGPoint
        switch slot {
        case 0: point = CGPoint(x: 0.08, y: 0.13)
        case 1: point = CGPoint(x: 0.58, y: 0.08)
        case 2: point = CGPoint(x: 0.92, y: 0.36)
        case 3: point = CGPoint(x: 0.50, y: 0.48)
        case 4: point = CGPoint(x: 0.92, y: 0.87)
        case 5: point = CGPoint(x: 0.39, y: 0.92)
        case 6: point = CGPoint(x: 0.08, y: 0.66)
        default: point = CGPoint(x: 0.48, y: 0.51)
        }
        let phase = Double(slot) * 1.71 + Double(fish) * 2.13
        let x = point.x + CGFloat(0.025 * sin(time * 0.019 + phase))
        let y = point.y + CGFloat(0.025 * cos(time * 0.017 + phase * 1.3))
        return CGPoint(x: fish.isMultiple(of: 2) ? x : 1 - x,
                       y: fish.isMultiple(of: 3) ? 1 - y : y)
    }

    private func currentTangent(_ index: Int, fish: Int, time: Double) -> CGPoint {
        let point = currentWaypoint(index, fish: fish, time: time)
        let before = currentWaypoint(index - 1, fish: fish, time: time)
        let after = currentWaypoint(index + 1, fish: fish, time: time)
        let dx = (after.x - before.x) * 0.30
        let dy = (after.y - before.y) * 0.30
        // Share the same tangent on both sides of every join; shorten handles symmetrically at edges.
        let scale = min(1, min(min(point.x, 1 - point.x) / max(abs(dx), 0.0001),
                               min(point.y, 1 - point.y) / max(abs(dy), 0.0001)))
        return CGPoint(x: dx * scale, y: dy * scale)
    }

    private func spine(at u: Double, length: CGFloat, phase: Double) -> CGPoint {
        let wave = sin(u * .pi * 2 - phase) - sin(.pi * 2 - phase)
        return CGPoint(x: length * CGFloat(u - 0.5),
                       y: length * CGFloat(0.065 * (1 - u) * wave))
    }

    private func spineTangent(at u: Double, length: CGFloat, phase: Double) -> CGPoint {
        let angle = u * .pi * 2 - phase
        let slope = 0.065 * (-(sin(angle) - sin(.pi * 2 - phase)) + (1 - u) * .pi * 2 * cos(angle))
        let magnitude = sqrt(1 + slope * slope)
        return CGPoint(x: 1 / magnitude, y: slope / magnitude)
    }

    private func softContour(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }
        path.move(to: CGPoint(x: (first.x + last.x) * 0.5, y: (first.y + last.y) * 0.5))
        for index in points.indices {
            let next = points[(index + 1) % points.count]
            path.addQuadCurve(to: CGPoint(x: (points[index].x + next.x) * 0.5,
                                          y: (points[index].y + next.y) * 0.5), control: points[index])
        }
        path.closeSubpath()
        return path
    }

    private func drawSurfaceGlints(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let count = min(42, max(20, Int(size.width / 18)))

        for index in 0..<count {
            let phase = Double(index) * 0.61
            let x = size.width * CGFloat(DriftNoise.hash(index, 3, seed: 430))
                + CGFloat(18.0 * sin(time * 0.05 + phase))
            let y = size.height * CGFloat(DriftNoise.hash(index, 7, seed: 430))
                + CGFloat(14.0 * cos(time * 0.04 + phase))
            let pulse = max(0.0, sin(time * 0.45 + phase))
            let radius = CGFloat(1.6 + 5.0 * pulse * DriftNoise.hash(index, 11, seed: 430))

            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.13 * pulse),
                        config.palette.tertiary.opacity(0.08 * pulse),
                        Color.clear
                    ]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: max(radius, 1)
                )
            )
        }
    }

    private func drawDepthVignette(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.32)
                ]),
                center: CGPoint(x: size.width * 0.50, y: size.height * 0.55),
                startRadius: min(size.width, size.height) * 0.20,
                endRadius: max(size.width, size.height) * 0.78
            )
        )
    }
}
