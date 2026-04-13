import SwiftUI

struct GravityRingsView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @State private var timelineStart: TimeInterval = Date().timeIntervalSinceReferenceDate

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            // Use a local time base to avoid a visible "jerk" on entry
            let effectiveDate = animationsPaused
            ? Date(timeIntervalSinceReferenceDate: timelineStart)
            : date
            let raw = effectiveDate.timeIntervalSinceReferenceDate - timelineStart
            let seconds = raw * max(0.25, speed)
            let t = seconds * 0.18

            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)

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
                        .blendMode(.screen)
                    )
                    .ignoresSafeArea()

                    // Rings: pulse (line width + opacity) and wiggle (subtle orbit + rotation)
                    // Some rings become circular "ripples" that switch over time.
                    Canvas { context, _ in
                        var ctx = context
                        renderRings(in: &ctx, size: size, center: center, t: t, seconds: seconds)
                    }
                    .ignoresSafeArea()
                }
                .onAppear { timelineStart = Date().timeIntervalSinceReferenceDate }
            }
        }
    }

    // MARK: - Ring Renderer

    private func renderRings(in context: inout GraphicsContext, size: CGSize, center: CGPoint, t: Double, seconds: Double) {
        let ringCount = 6
        // Keep the outermost strokes fully inside the screen bounds
        let minDim = min(size.width, size.height)
        let baseMaxRadius = (minDim * 0.5) - 28.0 // padding for thick glow strokes

        // Global drift for the whole ring system (slow, bouncing within safe bounds)
        // We keep enough margin so even the outer ring + glow stays inside the screen.
        let safeOuter = baseMaxRadius * 0.98
        let wobblePad: CGFloat = 16.0
        let extraPad: CGFloat = 10.0

        let marginX = min(size.width * 0.5 - 2.0, safeOuter + wobblePad + extraPad)
        let marginY = min(size.height * 0.5 - 2.0, safeOuter + wobblePad + extraPad)

        let rangeX = max(0.0, size.width - 2.0 * marginX)
        let rangeY = max(0.0, size.height - 2.0 * marginY)

        // Triangle waves act like slow “bounces” (reflecting at edges) without needing state.
        let bx = triangle01((seconds / 60.0) + 0.17)
        let by = triangle01((seconds / 68.0) + 0.53)

        let driftCenter = CGPoint(
            x: marginX + CGFloat(bx) * rangeX,
            y: marginY + CGFloat(by) * rangeY
        )

        // Global spacing drift: sometimes compresses rings so they overlap slightly
        let spacingDrift = CGFloat(1.0 - 0.05 * (0.5 + 0.5 * sin(t * 0.08)))

        // Switch which rings ripple slowly so the field feels hypnotic, not busy.
        let window = 9.0
        let k0 = Int(floor(t / window))
        let u = fract(t / window)
        let s = smoothstep(u)

        for i in 0..<ringCount {
            let phase = Double(i) * 0.9

            // Normalized ring spacing: ensures all rings fit within the screen
            let n = CGFloat(i) / CGFloat(max(1, ringCount - 1))
            let baseScale = 0.18 + 0.72 * n // 0.18 ... 0.90
            let scaleBase = baseScale * spacingDrift

            // Pulse envelope
            let pulse = 0.5 + 0.5 * sin(t * 0.62 + phase)
            let pulse2 = 0.5 + 0.5 * cos(t * 0.40 + phase * 1.3)

            // Wiggle: tiny orbital drift around center
            let wobX = CGFloat(7 * sin(t * 0.17 + phase) + 4 * sin(t * 0.30 + phase * 0.7))
            let wobY = CGFloat(7 * cos(t * 0.15 + phase) + 4 * cos(t * 0.28 + phase * 0.8))
            let wobScale = (0.28 + 0.08 * CGFloat(i))
            let ringCenter = CGPoint(x: driftCenter.x + wobX * wobScale, y: driftCenter.y + wobY * wobScale)

            // Slight additional per-ring convergence so adjacent rings can occasionally nudge into each other
            let converge = CGFloat(0.010 * sin(t * 0.12 + phase * 1.7))

            // Rotation shimmer
            let rot = CGFloat(t * 0.08 + phase * 0.25)

            // Compute a pixel radius from scale, then clamp so the full circle stays within bounds.
            let radiusRaw = baseMaxRadius * (scaleBase + 0.05 * CGFloat(pulse2) + converge)

            // Stroke weights (pulse affects width) — compute early so we can pad correctly
            let lw = 1.25 + CGFloat(1.05 * pulse)
            let maxStroke = (lw * 6.0) // widest glow stroke used below

            // Ripple parameters depend on radius; compute a provisional amplitude for padding
            let sel0 = rippleSelection(index: i, key: k0)
            let sel1 = rippleSelection(index: i, key: k0 + 1)
            let rippleMix = lerp(sel0, sel1, s) // 0..1
            let ampRaw = radiusRaw * CGFloat(0.012 + 0.010 * pulse) * CGFloat(rippleMix)

            // Edge-aware clamp: leave room for stroke + ripple peak
            let edge = min(ringCenter.x, size.width - ringCenter.x, ringCenter.y, size.height - ringCenter.y)
            let pad = (maxStroke * 0.5) + abs(ampRaw) + 3.0
            let radius = min(radiusRaw, max(0.0, edge - pad))

            // Final ripple amplitude (based on clamped radius)
            let amp = radius * CGFloat(0.012 + 0.010 * pulse) * CGFloat(rippleMix)

            // Ripple parameters: only some rings, but smoothly blended
            let lobes = 6 + (i % 3) * 2
            let ripplePhase = t * (0.66 + 0.06 * Double(i)) + phase * 0.8

            // Color gradient around the ring (approx by layered strokes)
            let c1 = config.palette.secondary.opacity(0.17 + 0.07 * pulse)
            let c2 = config.palette.tertiary.opacity(0.14 + 0.06 * pulse2)
            let c3 = config.palette.primary.opacity(0.12 + 0.05 * pulse)

            // Build path: circle when no ripple, rippled ring when selected
            let path = (rippleMix > 0.001)
                ? rippledRingPath(center: ringCenter,
                                  radius: radius,
                                  amp: amp,
                                  lobes: lobes,
                                  phase: ripplePhase,
                                  rotation: rot)
                : circlePath(center: ringCenter,
                             radius: radius)

            // Center glow (only the innermost ring)
            if i == 0 {
                let glowPulse = 0.5 + 0.5 * sin(t * 0.95 + phase * 0.6)
                let glowRadius = radius * (0.38 + 0.08 * CGFloat(glowPulse))

                let glowCenter = ringCenter

                let glowRect = CGRect(
                    x: glowCenter.x - glowRadius,
                    y: glowCenter.y - glowRadius,
                    width: glowRadius * 2,
                    height: glowRadius * 2
                )

                let core = config.palette.tertiary
                let glow = GraphicsContext.Shading.radialGradient(
                    Gradient(colors: [
                        core.opacity(0.17 + 0.10 * glowPulse),
                        core.opacity(0.08 + 0.06 * glowPulse),
                        Color.clear
                    ]),
                    center: glowCenter,
                    startRadius: 0,
                    endRadius: glowRadius
                )

                context.fill(Path(ellipseIn: glowRect), with: glow)
            }

            // Shadows (premium glow)
            context.stroke(path, with: .color(c1.opacity(0.07)), lineWidth: lw * 5.0)
            context.stroke(path, with: .color(c2.opacity(0.09)), lineWidth: lw * 2.4)
            context.stroke(path, with: .color(c1), lineWidth: lw)
            context.stroke(path, with: .color(c3.opacity(0.65)), lineWidth: max(0.8, lw * 0.55))
            context.stroke(path, with: .color(Color.white.opacity(0.05)), lineWidth: 0.75)
        }
    }

    private func rippleSelection(index: Int, key: Int) -> Double {
        // Select two rings to ripple per window; rotate selection over time.
        let a = (index + key * 2) % 6
        return (a == 1 || a == 4) ? 1.0 : 0.0
    }

    private func circlePath(center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private func rippledRingPath(center: CGPoint, radius: CGFloat, amp: CGFloat, lobes: Int, phase: Double, rotation: CGFloat) -> Path {
        let steps = 160
        var path = Path()

        for s in 0...steps {
            let u = Double(s) / Double(steps)
            let theta = (u * Double.pi * 2.0) + Double(rotation)

            // Radial ripple around the circle
            let r = radius + amp * CGFloat(sin(Double(lobes) * theta + phase))

            let x = center.x + r * CGFloat(cos(theta))
            let y = center.y + r * CGFloat(sin(theta))

            if s == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }

    private func fract(_ x: Double) -> Double { x - floor(x) }

    private func triangle01(_ x: Double) -> Double {
        // 0 → 1 → 0 repeating (like bouncing between edges)
        let f = fract(x)
        return 1.0 - abs(2.0 * f - 1.0)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private func smoothstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * (3.0 - 2.0 * t)
    }
}
