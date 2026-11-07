import SwiftUI

struct MeridianArcsView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused || reduceMotion) { date in
            let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            let effectiveSpeed = max(0.25, speed) * (isLowPower ? 0.75 : 1.0)
            let t = date.timeIntervalSinceReferenceDate * effectiveSpeed

            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.55)

                Canvas { context, _ in
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [config.palette.backgroundTop, config.palette.backgroundBottom]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: size.width, y: size.height)
                        )
                    )

                    // Soft bloom overlay to lift the scene for daytime viewing
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .radialGradient(
                            Gradient(colors: [
                                config.palette.primary.opacity(0.14),
                                config.palette.secondary.opacity(0.10),
                                Color.clear
                            ]),
                            center: center,
                            startRadius: 0,
                            endRadius: max(size.width, size.height) * 0.85
                        )
                    )

                    let arcCount = isLowPower ? 10 : 14
                    let steps = isLowPower ? 120 : 180

                    // Ripple selection switches smoothly over time (no popping)
                    let window = 6.0
                    let k0 = Int(floor(t / window))
                    let uWin = fract(t / window)
                    let sWin = smoothstep(uWin)

                    for i in 0..<arcCount {
                        let p = Double(i) / Double(max(1, arcCount - 1))

                        // Some arcs ripple; selection crossfades between windows
                        let sel0 = rippleSelection(index: i, key: k0)
                        let sel1 = rippleSelection(index: i, key: k0 + 1)
                        let rippleMix = lerp(sel0, sel1, sWin) // 0..1

                        let lobes = 8 + (i % 4) * 2
                        let ripplePhase = t * (0.55 + 0.05 * Double(i)) + Double(i) * 0.7

                        let outerRadius = min(min(size.width, size.height) * 0.60, size.width * 0.46)
                        let radiusX = outerRadius * (0.22 + 0.38 * p) / 0.60
                        let radiusY = radiusX * (0.55 + 0.10 * sin(t*0.05 + p*3))
                        let motion = MeridianArcsMotion.strand(index: i, count: arcCount, time: t)

                        var arc = Path()

                        for s in 0...steps {
                            let fraction = Double(s) / Double(steps)
                            let u = DriftNoise.lerp(motion.start, motion.end, fraction)
                            // Ripple is a small radial modulation around the arc (only for selected arcs)
                            let amp = (radiusX * 0.020) * rippleMix
                            let rMod = amp * sin(Double(lobes) * u + ripplePhase)
                                + radiusX * 0.028 * motion.flourish * sin(u * 4 - t * 0.45 + p * 2)
                            let point = motion.point(fraction: fraction, center: center,
                                                     radiusX: radiusX, radiusY: radiusY, ripple: rMod,
                                                     viewportHeight: size.height)
                            if s == 0 { arc.move(to: point) }
                            else { arc.addLine(to: point) }
                        }

                        let col: Color = (i % 3 == 0) ? config.palette.tertiary : (i % 3 == 1 ? config.palette.secondary : config.palette.primary)
                        // Layered glow so arcs read clearly
                        context.stroke(arc, with: .color(col.opacity(0.08)), lineWidth: 7.0)
                        context.stroke(arc, with: .color(col.opacity(0.14)), lineWidth: 3.2)
                        context.stroke(arc, with: .color(col.opacity(0.26)),
                                       style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                        context.stroke(arc, with: .color(Color.white.opacity(0.08)), lineWidth: 0.9)
                    }
                }
                .blur(radius: 0.45)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Ripple Helpers

    private func rippleSelection(index: Int, key: Int) -> Double {
        // Select ~1/3 of arcs per window; pattern rotates over time.
        let a = (index + key * 2) % 9
        return (a == 0 || a == 3 || a == 6) ? 1.0 : 0.0
    }

    private func fract(_ x: Double) -> Double { x - floor(x) }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private func smoothstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * (3.0 - 2.0 * t)
    }
}

/// Independent reaches share a single, infrequent roaming gesture; no timers or drawing state.
enum MeridianArcsMotion {
    struct Strand {
        let start: Double
        let end: Double
        let excursion: CGPoint
        let flourish: Double
        let lift: Double
        let liftCenter: Double

        func point(fraction: Double, center: CGPoint, radiusX: Double, radiusY: Double,
                   ripple: Double = 0, viewportHeight: Double = 0) -> CGPoint {
            let angle = start + (end - start) * fraction
            // Only the upper free end leaves its contour. A smooth falloff keeps the body attached.
            let attachment = MeridianArcsMotion.smooth((fraction - 0.70) / 0.30)
            var point = CGPoint(x: center.x + (radiusX + ripple) * cos(angle) + radiusX * excursion.x * attachment,
                                y: center.y + (radiusY + ripple * 0.85) * sin(angle) + radiusY * excursion.y * attachment)
            let local = (fraction - liftCenter) / 0.20
            if viewportHeight > 0, lift != 0, abs(local) < 1 {
                // A broad, soft crest lifts part of the ribbon; both ends remain attached.
                let crest = pow(0.5 + 0.5 * cos(local * .pi), 2)
                let room = lift < 0 ? center.y - radiusY - abs(ripple) * 0.85 - 12
                    : viewportHeight - center.y - radiusY - abs(ripple) * 0.85 - 12
                let height = min(max(0, room) * 0.70, radiusX * 0.65)
                point.y += height * lift * crest
                point.x += radiusX * 0.055 * lift * crest * sin(local * .pi)
            }
            return point
        }
    }

    static func strand(index: Int, count: Int, time: Double) -> Strand {
        let phase = Double(index) * 1.71
        let lowerReach = 0.5 - 0.5 * cos(time * (0.13 + Double(index % 5) * 0.009) + phase)
        let upperReach = 0.5 - 0.5 * cos(time * (0.16 + Double(index % 4) * 0.008) + phase * 1.31)
        let cycle = floor(time / 68)
        let clock = wrapped(time, period: 68)
        let traveler = count - 1 - Int(cycle) % max(1, count / 2)
        let roamingWindow = index == traveler ? envelope(clock, rise: 12, peak: 14, hold: 40, end: 42) : 0
        // Most reaches miss by a few pixels. A few contours occasionally hold a real meeting.
        let contactClock = wrapped(time + Double(index) * 7.9, period: 97)
        let contact = index % 4 == 1
            ? envelope(contactClock, rise: 25, peak: 29, hold: 30, end: 36) * (1 - roamingWindow) : 0
        let seam = 0.035 * sin(time * 0.07 + phase)
        let start = seam + (0.025 + 0.29 * (1 - lowerReach)) * (1 - contact)
        let end = .pi * 2 + seam - (0.025 + 0.29 * (1 - upperReach)) * (1 - contact)

        // One free end describes a broad, east-to-west loop, then curls home before the ripple settles.
        let q = smooth((clock - 14) / 26)
        let loop = sin(.pi * q)
        let roaming = index == traveler ? 1.0 : 0.0
        let excursion = CGPoint(x: -1.80 * loop * loop * roaming,
                                y: -0.82 * sin(.pi * 2 * q) * loop * roaming)
        let distance = abs(index - traveler)
        let flourish = envelope(clock, rise: 35, peak: 41, hold: 42, end: 54)
            * exp(-Double(distance) * 0.32)
        // Two staggered breaths use the space above and below, with a long quiet interval afterward.
        let liftCycle = Int(floor(time / 96))
        let liftClock = wrapped(time, period: 96)
        let upper = count - 3 - liftCycle % 3
        let lower = count - 6 - liftCycle % 2
        let lift: Double
        if index == upper {
            lift = -envelope(liftClock, rise: 6, peak: 22, hold: 24, end: 42)
        } else if index == lower {
            lift = envelope(liftClock, rise: 24, peak: 39, hold: 41, end: 59)
        } else {
            lift = 0
        }
        let liftCenter = (lift < 0 ? 0.73 : 0.25) + 0.035 * sin(time * 0.09 + phase)
        return Strand(start: start, end: end, excursion: excursion, flourish: flourish,
                      lift: lift, liftCenter: liftCenter)
    }

    private static func wrapped(_ value: Double, period: Double) -> Double {
        value - floor(value / period) * period
    }

    private static func envelope(_ value: Double, rise: Double, peak: Double, hold: Double, end: Double) -> Double {
        smooth((value - rise) / (peak - rise)) * (1 - smooth((value - hold) / (end - hold)))
    }

    private static func smooth(_ value: Double) -> Double {
        let u = min(1, max(0, value))
        return u * u * (3 - 2 * u)
    }
}
