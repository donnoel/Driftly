import SwiftUI

struct NeonKelpView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visitorRoute: NeonKelpVisitor.Route?

    var body: some View {
        PausableTimelineView(paused: animationsPaused || reduceMotion) { date in
            let time = date.timeIntervalSinceReferenceDate * max(0.25, speed)
            GeometryReader { proxy in
                let size = proxy.size
                Canvas { context, _ in
                    drawWater(in: context, size: size, time: time)
                    let count = NeonKelpGarden.count(in: size)
                    // Draw the distant plants first, then the fuller foreground fronds.
                    for index in (0..<count).filter({ $0.isMultiple(of: 2) }) {
                        drawFrond(index: index, count: count, in: context, size: size, time: time, distant: true, route: reduceMotion ? nil : visitorRoute)
                    }
                    for index in (0..<count).filter({ !$0.isMultiple(of: 2) }) {
                        drawFrond(index: index, count: count, in: context, size: size, time: time, distant: false, route: reduceMotion ? nil : visitorRoute)
                    }
                    drawMotes(in: context, size: size, time: time)
                    if !reduceMotion, let visitorRoute {
                        drawVisitor(in: context, size: size, time: time, route: visitorRoute)
                    }
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
                        Gradient(colors: [.clear, .black.opacity(0.25)]),
                        center: CGPoint(x: size.width * 0.5, y: size.height * 0.46),
                        startRadius: min(size.width, size.height) * 0.24,
                        endRadius: max(size.width, size.height) * 0.85
                    ))
                }
                .task(id: NeonKelpVisitor.RouteKey(size: size, time: time, enabled: !reduceMotion)) {
                    visitorRoute = reduceMotion ? nil : NeonKelpVisitor.route(size: size, time: time)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func drawWater(in context: GraphicsContext, size: CGSize, time: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
            startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
        ))
        context.fill(Path(rect), with: .radialGradient(
            Gradient(colors: [config.palette.tertiary.opacity(0.11), config.palette.secondary.opacity(0.09),
                              config.palette.primary.opacity(0.07), .clear]),
            center: CGPoint(x: size.width * 0.52, y: size.height * 0.48),
            startRadius: 0, endRadius: max(size.width, size.height) * 1.10
        ))
        // Keep the original, very slow vertical band of light behind the garden.
        let sweepX = size.width * (0.52 + sin(time * 0.072 * 0.075) * 0.34)
        let sweep = CGRect(x: sweepX - 130, y: 0, width: 260, height: size.height)
        context.fill(Path(sweep), with: .linearGradient(
            Gradient(colors: [.clear, .white.opacity(0.03), .clear]),
            startPoint: CGPoint(x: sweep.minX, y: 0), endPoint: CGPoint(x: sweep.maxX, y: 0)
        ))
    }

    private func tint(_ index: Int) -> Color {
        switch index % 3 {
        case 0: return Color(red: 0.35, green: 0.96, blue: 0.78)
        case 1: return Color(red: 0.54, green: 0.88, blue: 0.97)
        default: return config.palette.tertiary
        }
    }

    private func leafTint(_ index: Int) -> Color {
        switch index % 6 {
        case 0: return Color(red: 0.35, green: 0.96, blue: 0.78)
        case 1: return Color(red: 0.54, green: 0.88, blue: 0.97)
        case 2: return Color(red: 0.58, green: 0.65, blue: 1.00)
        case 3: return Color(red: 0.82, green: 0.54, blue: 0.97)
        case 4: return Color(red: 1.00, green: 0.55, blue: 0.77)
        default: return Color(red: 0.98, green: 0.79, blue: 0.54)
        }
    }

    private func drawFrond(index: Int, count: Int, in context: GraphicsContext,
                           size: CGSize, time: Double, distant: Bool, route: NeonKelpVisitor.Route?) {
        let base = min(size.width, size.height)
        var layer = context
        layer.opacity = distant ? 0.48 : 0.90
        let root = NeonKelpGarden.spine(0, index: index, count: count, size: size, time: time)
        let tip = NeonKelpGarden.spine(1, index: index, count: count, size: size, time: time)
        var stem = Path()
        for step in 0...48 {
            let point = NeonKelpGarden.spine(Double(step) / 48, index: index, count: count, size: size, time: time)
            if step == 0 { stem.move(to: point) } else { stem.addLine(to: point) }
        }
        layer.stroke(stem, with: .linearGradient(
            Gradient(colors: [.clear, tint(index).opacity(0.18), tint(index + 1).opacity(0.29), .clear]),
            startPoint: root, endPoint: tip
        ), style: StrokeStyle(lineWidth: max(1.2, base * 0.003), lineCap: .round))

        for leaf in 0..<6 {
            let id = NeonKelpGarden.LeafID(frond: index, blade: leaf)
            let geometry = NeonKelpGarden.leaf(id, size: size, time: time, dip: route?.dip(for: id, at: time) ?? 0)
            var blade = layer
            blade.translateBy(x: geometry.origin.x, y: geometry.origin.y)
            blade.rotate(by: .radians(geometry.angle))
            drawLeaf(in: blade, leaf: geometry, time: time, color: leafTint(index * 2 + leaf),
                     highlight: leafTint(index * 2 + leaf + 1))
        }
    }

    private func drawLeaf(in context: GraphicsContext, leaf: NeonKelpGarden.Leaf,
                          time: Double, color: Color, highlight: Color) {
        let length = leaf.length
        let width = leaf.width
        var upper: [CGPoint] = []
        var lower: [CGPoint] = []
        var vein = Path()
        let curl = leaf.curl(time: time)
        for step in 0...24 {
            let u = Double(step) / 24
            let sample = leaf.sample(u, time: time)
            let x = sample.center.x, y = sample.center.y
            let normal = sample.normal
            let edge = sample.edge
            upper.append(CGPoint(x: x - normal.x * edge * 0.85, y: y - normal.y * edge * 0.85))
            lower.append(CGPoint(x: x + normal.x * edge, y: y + normal.y * edge))
            if step == 0 { vein.move(to: CGPoint(x: x, y: y)) }
            else { vein.addLine(to: CGPoint(x: x, y: y)) }
        }
        var membrane = Path()
        for (index, point) in (upper + lower.reversed()).enumerated() {
            if index == 0 { membrane.move(to: point) } else { membrane.addLine(to: point) }
        }
        membrane.closeSubpath()
        context.fill(membrane, with: .linearGradient(
            Gradient(colors: [color.opacity(0.025), color.opacity(0.28),
                              highlight.opacity(0.35), color.opacity(0.08)]),
            startPoint: CGPoint(x: length * 0.12, y: -width),
            endPoint: CGPoint(x: length, y: width + length * CGFloat(curl))
        ))
        context.stroke(membrane, with: .color(color.opacity(0.075)),
                       style: StrokeStyle(lineWidth: 0.8, lineJoin: .round))
        // A silky central fold catches the moving light without turning the leaves into outlines.
        context.stroke(vein, with: .linearGradient(
            Gradient(colors: [.clear, Color.white.opacity(0.17), color.opacity(0.09), .clear]),
            startPoint: .zero, endPoint: CGPoint(x: length, y: length * CGFloat(curl))
        ), style: StrokeStyle(lineWidth: max(0.7, width * 0.035), lineCap: .round))
    }

    private func drawVisitor(in context: GraphicsContext, size: CGSize, time: Double, route: NeonKelpVisitor.Route) {
        guard let pose = route.pose(size: size, time: time) else { return }
        let radius = NeonKelpVisitor.radius(in: size)
        let opacity = min(1, min((time - route.startTime) / 0.9, (route.endTime - time) / 0.9))
        if let landing = route.hops.last(where: { $0.target != nil && $0.arrival <= time }) {
            let age = time - landing.arrival
            if age < 1.6, let id = landing.target {
                let foot = NeonKelpGarden.leaf(id, size: size, time: time,
                                               dip: route.dip(for: id, at: time)).perch(time: time)
                for index in 0..<3 {
                    let progress = age / 1.6
                    let x = foot.x + radius * Double(index - 1) * (0.8 + progress)
                    let y = foot.y - radius * (0.6 + progress * (1.6 + Double(index % 2)))
                    let r = radius * (0.12 + 0.04 * sin(Double(index)))
                    context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                 with: .color(Color(red: 1, green: 0.88, blue: 0.69)
                                    .opacity(opacity * 0.5 * sin(.pi * progress))))
                }
            }
        }
        var sprite = context
        sprite.opacity = opacity
        sprite.translateBy(x: pose.foot.x, y: pose.foot.y)
        sprite.scaleBy(x: pose.facing, y: 1)
        let stretch = pose.flight.map { sin($0 * .pi) } ?? 0
        sprite.translateBy(x: 0, y: -radius)
        sprite.rotate(by: .radians(-0.13 * stretch))
        sprite.scaleBy(x: 1 - 0.06 * stretch, y: 1 + 0.10 * stretch)
        sprite.translateBy(x: 0, y: radius)
        let glow = CGRect(x: -radius * 3, y: -radius * 4, width: radius * 6, height: radius * 6)
        sprite.fill(Path(ellipseIn: glow), with: .radialGradient(
            Gradient(colors: [Color(red: 1, green: 0.73, blue: 0.70).opacity(0.14), .clear]),
            center: CGPoint(x: 0, y: -radius), startRadius: 0, endRadius: radius * 3
        ))
        var tail = Path()
        tail.move(to: CGPoint(x: -radius * 0.55, y: -radius * 0.65))
        tail.addCurve(to: CGPoint(x: -radius * 2.0, y: -radius * (1.2 + 0.18 * sin(time * 0.7))),
                      control1: CGPoint(x: -radius * 2.6, y: radius * 0.4),
                      control2: CGPoint(x: -radius * 2.7, y: -radius * 2.0))
        sprite.stroke(tail, with: .color(Color(red: 0.94, green: 0.67, blue: 0.85).opacity(0.55)),
                      style: StrokeStyle(lineWidth: radius * 0.18, lineCap: .round))
        // Soft leaf-shaped fins and a warm, rounded belly distinguish this quiet visitor.
        for side in [-1.0, 1.0] {
            let flutter = 0.12 * sin(time * 0.75 + side)
            var fin = Path()
            fin.move(to: CGPoint(x: radius * side * 0.6, y: -radius * 1.0))
            fin.addQuadCurve(to: CGPoint(x: radius * side * (1.6 + flutter), y: -radius * 1.9),
                             control: CGPoint(x: radius * side * 1.3, y: -radius * 2.1))
            fin.addQuadCurve(to: CGPoint(x: radius * side * 0.7, y: -radius * 0.65),
                             control: CGPoint(x: radius * side * 1.6, y: -radius * 0.6))
            sprite.fill(fin, with: .linearGradient(
                Gradient(colors: [Color(red: 0.98, green: 0.80, blue: 0.84).opacity(0.5),
                                  Color(red: 0.66, green: 0.73, blue: 1).opacity(0.14)]),
                startPoint: CGPoint(x: 0, y: -radius), endPoint: CGPoint(x: radius * side * 1.6, y: -radius * 2)
            ))
        }
        sprite.fill(Path(ellipseIn: CGRect(x: -radius * 0.88, y: -radius * 1.95,
                                           width: radius * 1.76, height: radius * 1.95)),
                    with: .linearGradient(
                        Gradient(colors: [Color(red: 1, green: 0.94, blue: 0.84).opacity(0.85),
                                          Color(red: 0.95, green: 0.66, blue: 0.77).opacity(0.78),
                                          Color(red: 0.67, green: 0.65, blue: 0.91).opacity(0.65)]),
                        startPoint: CGPoint(x: 0, y: -radius * 2), endPoint: .zero
                    ))
        for x in [-0.28, 0.32] {
            var eye = Path()
            eye.move(to: CGPoint(x: radius * (x - 0.10), y: -radius * 1.04))
            eye.addQuadCurve(to: CGPoint(x: radius * (x + 0.10), y: -radius * 1.04),
                             control: CGPoint(x: radius * x, y: -radius * 0.90))
            sprite.stroke(eye, with: .color(Color(red: 0.13, green: 0.08, blue: 0.20).opacity(0.8)),
                          style: StrokeStyle(lineWidth: max(0.7, radius * 0.09), lineCap: .round))
        }
    }

    private func drawMotes(in context: GraphicsContext, size: CGSize, time: Double) {
        for index in 0..<36 {
            let phase = Double(index) * 2.399_963
            let drift = time * (0.002 + Double(index % 3) * 0.0003)
            let y = 1 - (Double(index) * 0.618 + drift).truncatingRemainder(dividingBy: 1)
            let x = 0.5 + 0.46 * sin(phase) + 0.015 * sin(time * 0.07 + phase)
            let radius = CGFloat(0.7 + 0.5 * sin(phase * 1.7))
            let alpha = 0.04 + 0.035 * (0.5 + 0.5 * sin(time * 0.18 + phase))
            context.fill(Path(ellipseIn: CGRect(x: size.width * x, y: size.height * y,
                                                width: radius * 2, height: radius * 3)),
                         with: .color(tint(index).opacity(alpha)))
        }
    }
}
