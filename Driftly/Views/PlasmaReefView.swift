import SwiftUI

struct PlasmaReefView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

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
        let slabCount = 26
        for i in 0..<slabCount {
            let p = Double(i) / Double(slabCount - 1)
            let phase = Double(i) * 0.83

            let laneY = size.height * CGFloat(0.12 + 0.78 * p)
            let driftY = CGFloat(18 * sin(t * 0.08 + phase) + 10 * cos(t * 0.05 + phase * 1.2))

            let baseW = size.width * CGFloat(0.18 + 0.28 * (0.5 + 0.5 * sin(phase * 1.7)))
            let baseH = size.height * CGFloat(0.010 + 0.020 * (0.5 + 0.5 * cos(phase * 1.3)))

            let slideSpeed = 14.0 + 10.0 * sin(phase)
            let slide = CGFloat((t * slideSpeed).truncatingRemainder(dividingBy: Double(size.width + baseW)))
            let x0 = -baseW + slide

            let shear = CGFloat(0.35 * sin(t * 0.06 + phase))
            let tilt = CGFloat(0.22 * sin(t * 0.05 + phase * 0.7))

            let rect = CGRect(x: x0, y: laneY + driftY, width: baseW, height: baseH)
            var slab = Path(roundedRect: rect, cornerRadius: baseH * 0.65)

            // Apply skew + tiny rotation for a "reef current" look
            let tx = rect.midX
            let ty = rect.midY
            let transform = CGAffineTransform(translationX: tx, y: ty)
                .rotated(by: tilt)
                .concatenating(CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0))
                .translatedBy(x: -tx, y: -ty)

            slab = slab.applying(transform)

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

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    var ctx = context
                    render(in: &ctx, size: size, t: t)
                }
                .blendMode(.screen)
                .blur(radius: 1.3)
                .compositingGroup()
            }
        }
    }
}
