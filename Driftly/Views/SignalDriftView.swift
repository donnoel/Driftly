import SwiftUI
import Combine
import os

struct SignalDriftView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
#if DEBUG
    private let diagnosticsEnabled = false
#endif

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

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
        }
    }
}


// MARK: - Cosmic Heart (Whimsical Pink)

private struct SignalPillowCloudLayer: View {
    let primary: Color
    let secondary: Color
    let t: Double
    @StateObject private var cache = PillowCache()

    var body: some View {
        GeometryReader { proxy in
            let s = proxy.size

            Canvas { context, _ in
#if DEBUG
                let interval = DebugMetrics.renderSignposter.beginInterval("render.frame")
                defer { DebugMetrics.renderSignposter.endInterval("render.frame", interval) }
#endif
                context.addFilter(.blur(radius: 22))
                cache.ensureSeeds(primary: primary, secondary: secondary)

                // Smooth drifting "mist pillows" (continuous motion, no wrap jumps)
                for seed in cache.seeds {
                    let phase = seed.phase
                    let x = s.width * CGFloat(seed.anchorX)
                        + CGFloat(seed.xDrift * sin(t * seed.freqX + phase))
                    let y = s.height * CGFloat(seed.anchorY)
                        + CGFloat(seed.yDrift * cos(t * seed.freqY + phase * 1.2))

                    let w = s.width * CGFloat(seed.baseW) * CGFloat(seed.wPulseBase + seed.wPulseAmp * (0.5 + 0.5 * sin(t * seed.wPulseFreq + phase)))
                    let h = s.height * CGFloat(seed.baseH) * CGFloat(seed.hPulseBase + seed.hPulseAmp * (0.5 + 0.5 * cos(t * seed.hPulseFreq + phase * 1.1)))

                    let shear = CGFloat(seed.shearAmp * sin(t * seed.shearFreq + phase))
                    let tilt = CGFloat(seed.tiltAmp * sin(t * seed.tiltFreq + phase * 0.9))

                    let rect = CGRect(x: x - w * 0.5, y: y - h * 0.5, width: w, height: h)
                    var pillow = Path(roundedRect: rect, cornerRadius: min(w, h) * 0.55)

                    let tx = rect.midX
                    let ty = rect.midY
                    let transform = CGAffineTransform(translationX: tx, y: ty)
                        .rotated(by: tilt)
                        .concatenating(CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0))
                        .translatedBy(x: -tx, y: -ty)

                    pillow = pillow.applying(transform)

                    let col = seed.color

                    // A richer, more cloud-like fill: layered strokes instead of a flat fill
                    context.fill(pillow, with: .color(col.opacity(0.14)))
                    context.stroke(pillow, with: .color(col.opacity(0.12)), lineWidth: 8.0)
                    context.stroke(pillow, with: .color(Color.white.opacity(0.06)), lineWidth: 1.0)
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct SignalHeartDriftLayer: View {
    let hotPink: Color
    let softPink: Color
    let t: Double
    @StateObject private var cache = HeartCache()

    var body: some View {
        GeometryReader { proxy in
            let s = proxy.size

            Canvas { context, _ in
                cache.ensureSeeds(hotPink: hotPink, softPink: softPink)

                for seed in cache.seeds {
                    let phase = seed.phase

                    let x = s.width * CGFloat(seed.anchorX)
                        + CGFloat(seed.xDrift * sin(t * seed.freqX + phase))
                        + CGFloat(seed.xPulse * sin(t * seed.freqX2 + phase * 1.7))

                    let y = s.height * CGFloat(seed.anchorY)
                        + CGFloat(seed.yDrift * cos(t * seed.freqY + phase * 1.2))
                        + CGFloat(seed.yPulse * cos(t * seed.freqY2 + phase * 1.9))

                    let pulseA = seed.pulseBaseA + seed.pulseAmpA * (0.5 + 0.5 * sin(t * seed.pulseFreqA + phase))
                    let pulseB = seed.pulseBaseB + seed.pulseAmpB * (0.5 + 0.5 * sin(t * seed.pulseFreqB + phase * 0.7))
                    let pulse = pulseA * pulseB

                    let rot = CGFloat(seed.rotAmpA * sin(t * seed.rotFreqA + phase) + seed.rotAmpB * cos(t * seed.rotFreqB + phase * 0.6))

                    let base = min(s.width, s.height)
                    let size = base * CGFloat(seed.sizeBase + seed.sizeAmp * (0.5 + 0.5 * sin(t * seed.sizeFreq + phase)))

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

                    let col = seed.color

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

// MARK: - Caches

@MainActor
private final class PillowCache: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    struct Seed {
        let phase: Double
        let anchorX: Double
        let anchorY: Double
        let xDrift: Double
        let yDrift: Double
        let freqX: Double
        let freqY: Double
        let baseW: Double
        let baseH: Double
        let wPulseBase: Double
        let wPulseAmp: Double
        let wPulseFreq: Double
        let hPulseBase: Double
        let hPulseAmp: Double
        let hPulseFreq: Double
        let shearAmp: Double
        let shearFreq: Double
        let tiltAmp: Double
        let tiltFreq: Double
        let color: Color
    }

    private(set) var seeds: [Seed] = []
    private var cachedColors: (Color, Color)?
    private let count = 12

    func ensureSeeds(primary: Color, secondary: Color) {
        if let cached = cachedColors, cached.0 == primary && cached.1 == secondary, seeds.count == count {
            return
        }
        cachedColors = (primary, secondary)

        seeds = (0..<count).map { i in
            let phase = Double(i) * 1.13
            let ax = hash01(i, 101)
            let ay = hash01(i, 202)

            let baseW = 0.26 + 0.22 * hash01(i, 303)
            let baseH = 0.08 + 0.06 * hash01(i, 404)

            let color = (i % 2 == 0) ? primary : secondary

            return Seed(
                phase: phase,
                anchorX: 0.10 + 0.80 * ax,
                anchorY: 0.10 + 0.80 * ay,
                xDrift: 90,
                yDrift: 70,
                freqX: 0.028 + 0.002 * Double(i),
                freqY: 0.024 + 0.002 * Double(i),
                baseW: baseW,
                baseH: baseH,
                wPulseBase: 0.86,
                wPulseAmp: 0.16,
                wPulseFreq: 0.06,
                hPulseBase: 0.88,
                hPulseAmp: 0.14,
                hPulseFreq: 0.05,
                shearAmp: 0.16,
                shearFreq: 0.035,
                tiltAmp: 0.12,
                tiltFreq: 0.030,
                color: color
            )
        }
        DebugMetrics.incrementCacheRebuild()
    }

    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
    }
}

@MainActor
private final class HeartCache: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    struct Seed {
        let phase: Double
        let anchorX: Double
        let anchorY: Double
        let xDrift: Double
        let xPulse: Double
        let yDrift: Double
        let yPulse: Double
        let freqX: Double
        let freqX2: Double
        let freqY: Double
        let freqY2: Double
        let pulseBaseA: Double
        let pulseAmpA: Double
        let pulseFreqA: Double
        let pulseBaseB: Double
        let pulseAmpB: Double
        let pulseFreqB: Double
        let rotAmpA: Double
        let rotAmpB: Double
        let rotFreqA: Double
        let rotFreqB: Double
        let sizeBase: Double
        let sizeAmp: Double
        let sizeFreq: Double
        let color: Color
    }

    private(set) var seeds: [Seed] = []
    private var cachedColors: (Color, Color)?
    private let count = 26
    private let palette: [Color] = [
        Color(red: 0.74, green: 0.38, blue: 1.00),
        Color(red: 1.00, green: 0.90, blue: 0.35),
        Color(red: 1.00, green: 0.28, blue: 0.74),
        Color(red: 0.56, green: 0.82, blue: 1.00)
    ]

    func ensureSeeds(hotPink: Color, softPink: Color) {
        if let cached = cachedColors, cached.0 == hotPink && cached.1 == softPink, seeds.count == count {
            return
        }
        cachedColors = (hotPink, softPink)

        seeds = (0..<count).map { i in
            let phase = Double(i) * 0.63
            let ax = hash01(i, 11)
            let ay = hash01(i, 22)

            let color: Color
            switch i % palette.count {
            case 0: color = palette[0]
            case 1: color = palette[1]
            case 2: color = palette[2]
            default: color = palette[3]
            }

            return Seed(
                phase: phase,
                anchorX: 0.10 + 0.80 * ax,
                anchorY: 0.10 + 0.80 * ay,
                xDrift: 120,
                xPulse: 40,
                yDrift: 95,
                yPulse: 36,
                freqX: 0.020 + 0.001 * Double(i),
                freqX2: 0.055,
                freqY: 0.018 + 0.001 * Double(i),
                freqY2: 0.050,
                pulseBaseA: 0.86,
                pulseAmpA: 0.22,
                pulseFreqA: 0.55,
                pulseBaseB: 0.96,
                pulseAmpB: 0.06,
                pulseFreqB: 1.35,
                rotAmpA: 0.30,
                rotAmpB: 0.10,
                rotFreqA: 0.08,
                rotFreqB: 0.11,
                sizeBase: 0.05,
                sizeAmp: 0.05,
                sizeFreq: 0.06,
                color: color
            )
        }
        DebugMetrics.incrementCacheRebuild()
    }

    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
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
