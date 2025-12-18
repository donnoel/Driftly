import SwiftUI

struct VelvetEclipseView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    // Background: velvet dark with a faint eclipse glow
                    let bgRect = CGRect(origin: .zero, size: size)
                    context.fill(
                        Path(bgRect),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    let eclipseCenter = CGPoint(
                        x: size.width * (0.52 + 0.04 * sin(t * 0.05)),
                        y: size.height * (0.48 + 0.03 * cos(t * 0.04))
                    )
                    let glow = GraphicsContext.Shading.radialGradient(
                        Gradient(colors: [
                            config.palette.secondary.opacity(0.10),
                            config.palette.primary.opacity(0.05),
                            Color.clear
                        ]),
                        center: eclipseCenter,
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.70
                    )
                    context.fill(Path(bgRect), with: glow)

                    // Shards: translucent glass fragments with color edges
                    let shardCount = 64
                    for i in 0..<shardCount {
                        let phase = Double(i) * 0.77
                        let isPulsing = (i % 5 == 0) || (i % 11 == 0)
                        let pulseUnit = 0.5 + 0.5 * sin(t * 0.70 + phase)
                        let pulseScale = isPulsing ? (0.82 + 0.28 * pulseUnit) : 1.0
                        let pulseEdgeBoost = isPulsing ? (0.10 + 0.18 * pulseUnit) : 0.0
                        let seed = 900 + i * 31

                        // Stable pseudo-random base placement
                        let rx = DriftNoise.hash(i, 11, seed: seed)
                        let ry = DriftNoise.hash(i, 27, seed: seed)

                        // Shatter field radiates from center, but drifts slowly
                        let angle = Double.pi * 2.0 * DriftNoise.hash(i, 73, seed: seed)
                        let radial = (0.10 + 0.45 * DriftNoise.hash(i, 99, seed: seed))
                        let drift = 0.015

                        let cx = size.width * (0.10 + 0.80 * CGFloat(rx))
                            + size.width * CGFloat(radial) * CGFloat(cos(angle + t * drift))
                        let cy = size.height * (0.10 + 0.80 * CGFloat(ry))
                            + size.height * CGFloat(radial) * CGFloat(sin(angle + t * drift))

                        let center = CGPoint(x: cx, y: cy)

                        // Fragment size + rotation
                        let base = min(size.width, size.height)
                        let w = base * CGFloat(0.10 + 0.16 * DriftNoise.hash(i, 7, seed: seed))
                        let h = base * CGFloat(0.06 + 0.14 * DriftNoise.hash(i, 8, seed: seed))
                        let rot = (t * 0.06 + phase) * (0.35 + 0.35 * DriftNoise.hash(i, 5, seed: seed))

                        // Build a fractured polygon (4–6 points)
                        let points = shardPoints(count: 4 + (i % 3), w: w, h: h, t: t, seed: seed)
                        var poly = Path()
                        if let first = points.first {
                            poly.move(to: first)
                            for p in points.dropFirst() { poly.addLine(to: p) }
                            poly.closeSubpath()
                        }

                        // Transform around local center
                        let tx = center.x
                        let ty = center.y
                        let transform = CGAffineTransform(translationX: tx, y: ty)
                            .rotated(by: CGFloat(rot))
                            .translatedBy(x: -tx, y: -ty)
                        poly = poly.applying(transform)
                        if isPulsing {
                            let scale = CGFloat(pulseScale)
                            let scaleTx = CGAffineTransform(translationX: center.x, y: center.y)
                                .scaledBy(x: scale, y: scale)
                                .translatedBy(x: -center.x, y: -center.y)
                            poly = poly.applying(scaleTx)
                        }

                        // Color selection
                        let col: Color
                        switch i % 3 {
                        case 0: col = config.palette.primary
                        case 1: col = config.palette.secondary
                        default: col = config.palette.tertiary
                        }

                        // Glass fill (very subtle)
                        context.fill(poly, with: .color(col.opacity(0.06)))

                        // Bright edge + inner highlight
                        context.stroke(poly, with: .color(col.opacity(0.22 + pulseEdgeBoost)), lineWidth: 1.4)
                        context.stroke(poly, with: .color(Color.white.opacity(0.06 + 0.4 * pulseEdgeBoost)), lineWidth: 0.8)

                        // Hairline crack (diagonal) for extra "shatter"
                        var crack = Path()
                        crack.move(to: CGPoint(x: center.x - w * 0.35, y: center.y - h * 0.15))
                        crack.addLine(to: CGPoint(x: center.x + w * 0.35, y: center.y + h * 0.22))
                        context.stroke(crack, with: .color(col.opacity(0.08)), lineWidth: 0.9)
                    }

                    // Secondary layer: many micro-shards for richer density
                    let microShardCount = 140
                    for i in 0..<microShardCount {
                        let phase = Double(i) * 0.41
                        let seed = 1600 + i * 17

                        let rx = DriftNoise.hash(i, 101, seed: seed)
                        let ry = DriftNoise.hash(i, 202, seed: seed)

                        // Gentle drift so they feel suspended
                        let dx = CGFloat(18 * sin(t * 0.03 + phase))
                        let dy = CGFloat(14 * cos(t * 0.028 + phase * 1.2))

                        let center = CGPoint(
                            x: size.width * CGFloat(rx) + dx,
                            y: size.height * CGFloat(ry) + dy
                        )

                        let base = min(size.width, size.height)
                        let w = base * CGFloat(0.028 + 0.050 * DriftNoise.hash(i, 303, seed: seed))
                        let h = base * CGFloat(0.018 + 0.045 * DriftNoise.hash(i, 404, seed: seed))

                        // Occasional pulse/glint
                        let isGlint = (i % 13 == 0)
                        let glint = 0.5 + 0.5 * sin(t * 0.85 + phase * 0.7)
                        let glintBoost = isGlint ? (0.04 + 0.10 * glint) : 0.0

                        let rot = CGFloat((t * 0.09 + phase) * (0.35 + 0.55 * DriftNoise.hash(i, 505, seed: seed)))

                        let points = microShardPoints(count: 3 + (i % 2), w: w, h: h, t: t, seed: seed)
                        var poly = Path()
                        if let first = points.first {
                            poly.move(to: first)
                            for p in points.dropFirst() { poly.addLine(to: p) }
                            poly.closeSubpath()
                        }

                        // Transform around micro center
                        let transform = CGAffineTransform(translationX: center.x, y: center.y)
                            .rotated(by: rot)
                            .translatedBy(x: -center.x, y: -center.y)
                        poly = poly.applying(transform)

                        // Color selection (slightly more varied)
                        let col: Color
                        switch i % 3 {
                        case 0: col = config.palette.primary
                        case 1: col = config.palette.secondary
                        default: col = config.palette.tertiary
                        }

                        // Fill + edge
                        context.fill(poly, with: .color(col.opacity(0.035 + glintBoost)))
                        context.stroke(poly, with: .color(col.opacity(0.10 + glintBoost)), lineWidth: 0.9)
                        context.stroke(poly, with: .color(Color.white.opacity(0.03 + 0.35 * glintBoost)), lineWidth: 0.6)
                    }

                    // Micro dust specks (tiny glints)
                    let specks = 260
                    for i in 0..<specks {
                        let u = Double(i) * 0.37
                        let x = size.width * CGFloat(DriftNoise.fract(0.13 * u + 0.010 * t))
                        let y = size.height * CGFloat(DriftNoise.fract(0.17 * u + 0.008 * t + 0.2))
                        let a = 0.02 + 0.05 * DriftNoise.hash(i, 3, seed: 777)
                        let r = 0.6 + 1.6 * DriftNoise.hash(i, 9, seed: 777)
                        let c: Color = (i % 2 == 0) ? config.palette.secondary : config.palette.primary
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(c.opacity(a)))
                    }
                }
                .blendMode(.screen)
                .blur(radius: 0.9)
                .compositingGroup()
            }
        }
    }

    private func shardPoints(count: Int, w: CGFloat, h: CGFloat, t: Double, seed: Int) -> [CGPoint] {
        let n = max(3, min(8, count))
        var pts: [CGPoint] = []
        pts.reserveCapacity(n)

        // Local center anchors around mid-screen-ish; points are absolute, so we start near center and offset.
        // We purposely bias shapes to look like broken panes (more trapezoids than perfect polygons).
        let cx = CGFloat(0.5)
        let cy = CGFloat(0.5)

        for i in 0..<n {
            let p = Double(i) / Double(n)
            let a = (p * Double.pi * 2.0) + 0.35 * DriftNoise.hash(i, 19, seed: seed)
            let jitter = 0.65 + 0.55 * DriftNoise.hash(i, 23, seed: seed)
            let pulse = 0.96 + 0.06 * sin(t * 0.08 + Double(seed) * 0.001 + p * 6.0)

            let rx = w * CGFloat(0.45 + 0.55 * cos(a)) * CGFloat(jitter) * CGFloat(pulse)
            let ry = h * CGFloat(0.45 + 0.55 * sin(a)) * CGFloat(0.85 + 0.30 * jitter) * CGFloat(pulse)

            // Skew the polygon slightly so it feels fractured
            let skew = CGFloat(0.18 * sin(t * 0.05 + Double(seed) * 0.01))
            let x = cx + (rx / max(w, 1)) + skew * (ry / max(h, 1))
            let y = cy + (ry / max(h, 1))

            // Convert normalized offsets into absolute points around the origin; actual placement is handled in the caller
            // by translating with `center`.
            pts.append(CGPoint(x: x * w, y: y * h))
        }

        // Re-center around (0,0) and let caller translate via CGAffineTransform
        let minX = pts.map(\.x).min() ?? 0
        let maxX = pts.map(\.x).max() ?? 0
        let minY = pts.map(\.y).min() ?? 0
        let maxY = pts.map(\.y).max() ?? 0
        let ox = (minX + maxX) * 0.5
        let oy = (minY + maxY) * 0.5
        return pts.map { CGPoint(x: $0.x - ox, y: $0.y - oy) }
    }
    
    private func microShardPoints(count: Int, w: CGFloat, h: CGFloat, t: Double, seed: Int) -> [CGPoint] {
        let n = max(3, min(6, count))
        var pts: [CGPoint] = []
        pts.reserveCapacity(n)

        // Small fractured triangles/quads; keep them jagged but stable
        for i in 0..<n {
            let p = Double(i) / Double(n)
            let a = (p * Double.pi * 2.0) + 0.55 * DriftNoise.hash(i, 61, seed: seed)
            let jitter = 0.70 + 0.60 * DriftNoise.hash(i, 73, seed: seed)
            let pulse = 0.98 + 0.04 * sin(t * 0.06 + Double(seed) * 0.002 + p * 5.0)

            let rx = w * CGFloat(0.35 + 0.65 * cos(a)) * CGFloat(jitter) * CGFloat(pulse)
            let ry = h * CGFloat(0.35 + 0.65 * sin(a)) * CGFloat(0.85 + 0.25 * jitter) * CGFloat(pulse)

            // Slight skew to feel like splintered glass
            let skew = CGFloat(0.12 * sin(t * 0.04 + Double(seed) * 0.01))
            let x = (rx / max(w, 1)) + skew * (ry / max(h, 1))
            let y = (ry / max(h, 1))

            pts.append(CGPoint(x: x * w, y: y * h))
        }

        // Center around (0,0)
        let minX = pts.map(\.x).min() ?? 0
        let maxX = pts.map(\.x).max() ?? 0
        let minY = pts.map(\.y).min() ?? 0
        let maxY = pts.map(\.y).max() ?? 0
        let ox = (minX + maxX) * 0.5
        let oy = (minY + maxY) * 0.5
        return pts.map { CGPoint(x: $0.x - ox, y: $0.y - oy) }
    }
}
