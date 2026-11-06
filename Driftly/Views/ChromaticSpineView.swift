import SwiftUI

struct ChromaticSpineView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused || reduceMotion) { date in
            let time = date.timeIntervalSinceReferenceDate * max(0.25, speed)
            GeometryReader { proxy in
                Canvas { context, _ in
                    render(in: context, size: proxy.size, time: time)
                }
                .blur(radius: 0.5)
            }
            .ignoresSafeArea()
        }
    }

    private func render(in context: GraphicsContext, size: CGSize, time: Double) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
            startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
        ))
        let circles = (0..<3).map { ChromaticSpineMotion.circle(index: $0, size: size, time: time) }
        // Sample this one shared, bending spine once; ribs and tendril roots follow its actual geometry.
        let points = (0...90).map { ChromaticSpineMotion.spinePoint(u: Double($0) / 90,
                                                                  size: size, time: time, circles: circles) }
        drawDancingSpine(in: context, points: points, time: time)
        for index in 0..<5 {
            drawTendril(index: index, root: points[15 + index * 13], circles: circles,
                        in: context, size: size, time: time)
        }
        for (index, circle) in circles.enumerated() {
            drawCircle(circle, index: index, in: context, time: time)
        }
    }

    private func tint(_ index: Int) -> Color {
        switch index % 3 {
        case 0: return config.palette.secondary
        case 1: return Color(red: 1, green: 0.40, blue: 0.82)
        default: return config.palette.tertiary
        }
    }

    private func drawDancingSpine(in context: GraphicsContext, points: [CGPoint], time: Double) {
        var spine = Path()
        for (index, point) in points.enumerated() {
            if index == 0 { spine.move(to: point) } else { spine.addLine(to: point) }
        }
        context.stroke(spine, with: .color(config.palette.secondary.opacity(0.045)),
                       style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
        for index in 1..<(points.count - 1) {
            let center = points[index]
            let dx = points[index + 1].x - points[index - 1].x
            let dy = points[index + 1].y - points[index - 1].y
            let length = max(0.001, hypot(dx, dy))
            let phase = Double(index) * 0.21
            let width = CGFloat(12 + 12 * (0.5 + 0.5 * sin(time * 0.19 + phase)))
            let normal = CGPoint(x: -dy / length, y: dx / length)
            var rib = Path()
            rib.move(to: CGPoint(x: center.x - normal.x * width, y: center.y - normal.y * width))
            rib.addLine(to: CGPoint(x: center.x + normal.x * width, y: center.y + normal.y * width))
            context.stroke(rib, with: .color(tint(index).opacity(0.10 + 0.035 * sin(time * 0.12 + phase))),
                           lineWidth: 1.1)
        }
    }

    private func drawTendril(index: Int, root: CGPoint, circles: [ChromaticSpineMotion.Circle],
                             in context: GraphicsContext, size: CGSize, time: Double) {
        let circle = circles[index % circles.count]
        let gesture = ChromaticSpineMotion.gesture(index: index, circle: circle, size: size, time: time)
        let base = min(size.width, size.height)
        let phase = Double(index) * 1.37
        let dx = gesture.tip.x - root.x
        let dy = gesture.tip.y - root.y
        let distance = max(1, hypot(dx, dy))
        let side = CGFloat(index.isMultiple(of: 2) ? 1.0 : -1.0)
        let curl = base * CGFloat(0.13 + 0.055 * sin(time * 0.23 + phase)) * side
        let tangent = CGPoint(x: -gesture.normal.y, y: gesture.normal.x)
        var strand = Path()
        strand.move(to: root)
        strand.addCurve(to: gesture.tip,
                        control1: CGPoint(x: root.x + dx * 0.28 - dy / distance * curl,
                                          y: root.y + dy * 0.28 + dx / distance * curl),
                        control2: CGPoint(x: gesture.tip.x + gesture.normal.x * base * 0.10
                                            + tangent.x * curl * 0.65,
                                          y: gesture.tip.y + gesture.normal.y * base * 0.10
                                            + tangent.y * curl * 0.65))
        let color = tint(index)
        context.stroke(strand, with: .color(color.opacity(0.075)),
                       style: StrokeStyle(lineWidth: index == 0 ? 14 : 10, lineCap: .round))
        context.stroke(strand, with: .linearGradient(
            Gradient(colors: [color.opacity(0.14), color.opacity(0.32), config.palette.primary.opacity(0.20)]),
            startPoint: root, endPoint: gesture.tip
        ), style: StrokeStyle(lineWidth: index == 0 ? 4.5 : 3, lineCap: .round))
        context.stroke(strand, with: .color(Color.white.opacity(0.11)),
                       style: StrokeStyle(lineWidth: 1, lineCap: .round))
        let glowRadius = max(4, base * 0.019)
        let contact = pow(gesture.reach, 8)
        context.fill(Path(ellipseIn: CGRect(x: gesture.tip.x - glowRadius, y: gesture.tip.y - glowRadius,
                                            width: glowRadius * 2, height: glowRadius * 2)),
                     with: .radialGradient(Gradient(colors: [color.opacity(0.19 * contact), .clear]),
                                           center: gesture.tip, startRadius: 0, endRadius: glowRadius))
    }

    private func drawCircle(_ circle: ChromaticSpineMotion.Circle, index: Int,
                            in context: GraphicsContext, time: Double) {
        var loop = Path()
        for step in 0..<120 {
            let angle = Double(step) * .pi * 2 / 120
            let point = circle.point(angle: angle, time: time)
            if step == 0 { loop.move(to: point) } else { loop.addLine(to: point) }
        }
        loop.closeSubpath()
        let color = tint(index)
        let start = circle.point(angle: time * 0.06, time: time)
        let end = circle.point(angle: time * 0.06 + .pi, time: time)
        context.stroke(loop, with: .color(color.opacity(0.055)), lineWidth: 11)
        context.stroke(loop, with: .linearGradient(
            Gradient(colors: [color.opacity(0.16), color.opacity(0.40), Color.white.opacity(0.23), color.opacity(0.10)]),
            startPoint: start, endPoint: end
        ), lineWidth: 1.6)
    }
}

/// Shared geometry makes a tendril meet the moving, flexing circle instead of an approximate target.
enum ChromaticSpineMotion {
    struct Circle {
        let center: CGPoint
        let radius: CGFloat
        let phase: Double

        func edgeRadius(angle: Double, time: Double) -> CGFloat {
            radius * CGFloat(1 + 0.018 * sin(angle * 3 + time * 0.18 + phase))
        }

        func point(angle: Double, time: Double) -> CGPoint {
            let r = edgeRadius(angle: angle, time: time)
            return CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
        }
    }

    struct Gesture {
        let tip: CGPoint
        let normal: CGPoint
        let reach: Double
    }

    static func circle(index: Int, size: CGSize, time: Double) -> Circle {
        let phase = Double(index) * 2.1
        let center = CGPoint(x: size.width * CGFloat(0.5 + 0.30 * sin(time * 0.063 + phase)),
                             y: size.height * CGFloat(0.5 + 0.30 * sin(time * 0.048 + phase * 1.7)))
        return Circle(center: center,
                      radius: min(size.width, size.height) * CGFloat(0.095 + 0.018 * sin(phase + 0.7)),
                      phase: phase)
    }

    static func gesture(index: Int, circle: Circle, size: CGSize, time: Double) -> Gesture {
        let phase = Double(index) * 1.37
        let reach = pow(0.5 - 0.5 * cos(time * 0.40 + phase), 2)
        let angle = time * 0.14 + phase
        let normal = CGPoint(x: cos(angle), y: sin(angle))
        let edge = circle.edgeRadius(angle: angle, time: time)
        let roomX = normal.x >= 0 ? (size.width - 10 - circle.center.x) / max(normal.x, 0.0001)
            : (10 - circle.center.x) / min(normal.x, -0.0001)
        let roomY = normal.y >= 0 ? (size.height - 10 - circle.center.y) / max(normal.y, 0.0001)
            : (10 - circle.center.y) / min(normal.y, -0.0001)
        let retreat = min(min(size.width, size.height) * 0.18, max(0, min(roomX, roomY) - edge))
        let radius = edge + retreat * CGFloat(1 - reach)
        return Gesture(tip: CGPoint(x: circle.center.x + normal.x * radius,
                                    y: circle.center.y + normal.y * radius), normal: normal, reach: reach)
    }

    static func spinePoint(u: Double, size: CGSize, time: Double, circles: [Circle]) -> CGPoint {
        let base = min(size.width, size.height)
        var point = CGPoint(x: size.width * CGFloat(0.5 + 0.27 * sin(u * .pi * 2 - time * 0.075)
                                                     + 0.10 * sin(time * 0.042)),
                            y: size.height * CGFloat(0.08 + 0.84 * u)
                                + base * CGFloat(0.065 * sin(time * 0.09 + u * 5)))
        // A soft field bends the striped spine around the loops as they wander through it.
        for circle in circles {
            let dx = point.x - circle.center.x
            let dy = point.y - circle.center.y
            let distance = sqrt(dx * dx + dy * dy + 16)
            let range = circle.radius + base * 0.11
            let influence = exp(-pow(Double(distance / range), 2))
            let push = base * CGFloat(0.12 * influence)
            point.x += dx / distance * push
            point.y += dy / distance * push
        }
        return point
    }
}
