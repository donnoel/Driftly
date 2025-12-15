import SwiftUI

struct SignalDriftView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * max(0.25, speed)

            ZStack {
                // Pink velvet backdrop
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.02, blue: 0.09),
                        Color(red: 0.18, green: 0.03, blue: 0.14),
                        Color(red: 0.08, green: 0.02, blue: 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Soft, drifting cloud pillows (no circles)
                SignalPillowCloudLayer(
                    primary: Color(red: 1.00, green: 0.62, blue: 0.86),
                    secondary: Color(red: 0.98, green: 0.44, blue: 0.78),
                    t: t
                )
                .blendMode(.screen)
                .opacity(0.65)
                .blur(radius: 26)

                // Floating hearts (calm, not confetti)
                SignalHeartDriftLayer(
                    hotPink: Color(red: 1.00, green: 0.28, blue: 0.74),
                    softPink: Color(red: 1.00, green: 0.70, blue: 0.88),
                    t: t
                )
                .blendMode(.screen)
                .opacity(0.70)
                .blur(radius: 1.2)

                // A dreamy glow vignette to make it feel premium
                SignalDreamGlowVignette(
                    top: Color(red: 1.00, green: 0.36, blue: 0.78),
                    bottom: Color(red: 0.55, green: 0.18, blue: 0.45),
                    t: t
                )
                .blendMode(.screen)
                .opacity(0.55)
            }
            .compositingGroup()
        }
    }
}


// MARK: - Cosmic Heart (Whimsical Pink)

private struct SignalPillowCloudLayer: View {
    let primary: Color
    let secondary: Color
    let t: Double

    var body: some View {
        GeometryReader { proxy in
            let s = proxy.size

            Canvas { context, _ in
                // Smooth drifting "mist pillows" (continuous motion, no wrap jumps)
                let count = 12
                for i in 0..<count {
                    let phase = Double(i) * 1.13

                    // Stable anchors (0..1) per item
                    let ax = hash01(i, 101)
                    let ay = hash01(i, 202)

                    // Continuous drift around anchor
                    let x = s.width * CGFloat(0.10 + 0.80 * ax)
                        + CGFloat(90 * sin(t * (0.028 + 0.002 * Double(i)) + phase))
                    let y = s.height * CGFloat(0.10 + 0.80 * ay)
                        + CGFloat(70 * cos(t * (0.024 + 0.002 * Double(i)) + phase * 1.2))

                    // Soft, pillowy dimensions
                    let w = s.width * CGFloat(0.26 + 0.22 * hash01(i, 303))
                        * CGFloat(0.86 + 0.16 * (0.5 + 0.5 * sin(t * 0.06 + phase)))
                    let h = s.height * CGFloat(0.08 + 0.06 * hash01(i, 404))
                        * CGFloat(0.88 + 0.14 * (0.5 + 0.5 * cos(t * 0.05 + phase * 1.1)))

                    // Gentle skew + tilt (still pillow-like, but organic)
                    let shear = CGFloat(0.16 * sin(t * 0.035 + phase))
                    let tilt = CGFloat(0.12 * sin(t * 0.030 + phase * 0.9))

                    let rect = CGRect(x: x - w * 0.5, y: y - h * 0.5, width: w, height: h)
                    var pillow = Path(roundedRect: rect, cornerRadius: min(w, h) * 0.55)

                    let tx = rect.midX
                    let ty = rect.midY
                    let transform = CGAffineTransform(translationX: tx, y: ty)
                        .rotated(by: tilt)
                        .concatenating(CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0))
                        .translatedBy(x: -tx, y: -ty)

                    pillow = pillow.applying(transform)

                    let col = (i % 2 == 0) ? primary : secondary

                    // A richer, more cloud-like fill: layered strokes instead of a flat fill
                    context.fill(pillow, with: .color(col.opacity(0.14)))
                    context.stroke(pillow, with: .color(col.opacity(0.12)), lineWidth: 8.0)
                    context.stroke(pillow, with: .color(Color.white.opacity(0.06)), lineWidth: 1.0)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
    }
}

private struct SignalHeartDriftLayer: View {
    let hotPink: Color
    let softPink: Color
    let t: Double

    var body: some View {
        GeometryReader { proxy in
            let s = proxy.size

            Canvas { context, _ in
                let colors: [Color] = [
                    Color(red: 0.74, green: 0.38, blue: 1.00), // purple
                    Color(red: 1.00, green: 0.90, blue: 0.35), // yellow
                    Color(red: 1.00, green: 0.28, blue: 0.74), // pink
                    Color(red: 0.56, green: 0.82, blue: 1.00)  // baby blue
                ]

                let count = 26
                for i in 0..<count {
                    let phase = Double(i) * 0.63

                    // Stable anchors per heart
                    let ax = hash01(i, 11)
                    let ay = hash01(i, 22)

                    // Smooth wandering around anchor (no wrap)
                    let x = s.width * CGFloat(0.10 + 0.80 * ax)
                        + CGFloat(120 * sin(t * (0.020 + 0.001 * Double(i)) + phase))
                        + CGFloat(40 * sin(t * 0.055 + phase * 1.7))

                    let y = s.height * CGFloat(0.10 + 0.80 * ay)
                        + CGFloat(95 * cos(t * (0.018 + 0.001 * Double(i)) + phase * 1.2))
                        + CGFloat(36 * cos(t * 0.050 + phase * 1.9))

                    // Bigger, clearer cuddle-pulse + a tiny secondary heartbeat flutter
                    let pulseA = 0.86 + 0.22 * (0.5 + 0.5 * sin(t * 0.55 + phase))
                    let pulseB = 0.96 + 0.06 * (0.5 + 0.5 * sin(t * 1.35 + phase * 0.7))
                    let pulse = pulseA * pulseB

                    let rot = CGFloat(0.30 * sin(t * 0.08 + phase) + 0.10 * cos(t * 0.11 + phase * 0.6))

                    let base = min(s.width, s.height)
                    let size = base * CGFloat(0.05 + 0.05 * (0.5 + 0.5 * sin(t * 0.06 + phase)))

                    let rect = CGRect(x: x - size * 0.5, y: y - size * 0.5, width: size, height: size)
                    var heart = HeartShape().path(in: rect)

                    // Rotate + pulse around local center
                    let tx = rect.midX
                    let ty = rect.midY
                    let transform = CGAffineTransform(translationX: tx, y: ty)
                        .rotated(by: rot)
                        .scaledBy(x: CGFloat(pulse), y: CGFloat(pulse))
                        .translatedBy(x: -tx, y: -ty)
                    heart = heart.applying(transform)

                    let col = colors[i % colors.count]

                    // Fill + glow-ish layered edges
                    context.fill(heart, with: .color(col.opacity(0.16)))
                    context.stroke(heart, with: .color(col.opacity(0.26)), lineWidth: 1.2)
                    context.stroke(heart, with: .color(col.opacity(0.12)), lineWidth: 5.0)
                    context.stroke(heart, with: .color(Color.white.opacity(0.07)), lineWidth: 0.9)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
    }
}

private struct SignalDreamGlowVignette: View {
    let top: Color
    let bottom: Color
    let t: Double

    var body: some View {
        GeometryReader { proxy in
            let s = proxy.size
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            top.opacity(0.16),
                            bottom.opacity(0.10),
                            Color.clear
                        ],
                        center: UnitPoint(
                            x: 0.50 + 0.10 * sin(t * 0.04),
                            y: 0.45 + 0.08 * cos(t * 0.03)
                        ),
                        startRadius: 0,
                        endRadius: max(s.width, s.height) * 0.95
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.25), Color.clear, Color.black.opacity(0.38)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.multiply)
                )
                .ignoresSafeArea()
        }
    }
}

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY

        var p = Path()
        // A smooth heart using cubic curves
        p.move(to: CGPoint(x: x + 0.5 * w, y: y + 0.92 * h))
        p.addCurve(
            to: CGPoint(x: x + 0.06 * w, y: y + 0.40 * h),
            control1: CGPoint(x: x + 0.25 * w, y: y + 0.85 * h),
            control2: CGPoint(x: x + 0.05 * w, y: y + 0.65 * h)
        )
        p.addCurve(
            to: CGPoint(x: x + 0.50 * w, y: y + 0.18 * h),
            control1: CGPoint(x: x + 0.06 * w, y: y + 0.22 * h),
            control2: CGPoint(x: x + 0.30 * w, y: y + 0.10 * h)
        )
        p.addCurve(
            to: CGPoint(x: x + 0.94 * w, y: y + 0.40 * h),
            control1: CGPoint(x: x + 0.70 * w, y: y + 0.10 * h),
            control2: CGPoint(x: x + 0.94 * w, y: y + 0.22 * h)
        )
        p.addCurve(
            to: CGPoint(x: x + 0.50 * w, y: y + 0.92 * h),
            control1: CGPoint(x: x + 0.95 * w, y: y + 0.65 * h),
            control2: CGPoint(x: x + 0.75 * w, y: y + 0.85 * h)
        )
        p.closeSubpath()
        return p
    }
}
