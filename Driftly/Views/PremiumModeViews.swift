import SwiftUI

struct CausticSilkView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused || reduceMotion) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    render(in: context, size: size, time: t)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func render(in context: GraphicsContext, size: CGSize, time t: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.tertiary.opacity(0.14),
                    config.palette.primary.opacity(0.08),
                    Color.clear
                ]),
                center: CGPoint(x: size.width * 0.48, y: size.height * 0.45),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.95
            )
        )

        var glow = context
        glow.blendMode = .plusLighter

        drawMusicalNotes(
            in: &glow,
            size: size,
            time: t,
            count: lineCount(for: size, divisor: 110, minimum: 10, maximum: 16)
        )
        drawCausticFamily(
            in: &glow,
            size: size,
            time: t,
            family: 2,
            count: lineCount(for: size, divisor: 94, minimum: 5, maximum: 10)
        )

        drawGlints(in: &glow, size: size, time: t)
        drawVignette(in: context, size: size)
    }

    /// Slender, calligraphic notes float through the silk like a quiet, unwritten melody.
    private func drawMusicalNotes(
        in context: inout GraphicsContext,
        size: CGSize,
        time t: Double,
        count: Int
    ) {
        let base = min(size.width, size.height)
        for index in 0..<count {
            let phase = Double(index) * 1.73
            let rx = DriftNoise.fract((Double(index) + 0.5) * 0.61803398875)
            let ry = DriftNoise.fract((Double(index) + 0.5) * 0.754877666 + 0.23)
            let center = CGPoint(
                x: size.width * CGFloat(0.12 + 0.76 * rx + 0.075 * sin(t * (0.078 + 0.006 * Double(index % 3)) + phase)),
                y: size.height * CGFloat(0.15 + 0.71 * ry + 0.075 * cos(t * 0.071 + phase * 1.3))
            )
            let unit = max(3.8, base * CGFloat(0.010 + 0.003 * DriftNoise.hash(index, 19, seed: 1200)))
            let pulse = 0.5 + 0.5 * sin(t * 0.14 + phase)
            let color = musicalTint(phase: t * 0.045 + phase)
            let accent = musicalTint(phase: t * 0.045 + phase + 2.1)
            let kind = index % 6
            var note = context
            note.translateBy(x: center.x, y: center.y)
            note.rotate(by: .radians(0.15 * sin(phase) + 0.10 * sin(t * 0.085 + phase)))
            note.scaleBy(x: unit, y: unit)

            var head = Path(ellipseIn: CGRect(x: -1.25, y: -0.72, width: 2.5, height: 1.44))
                .applying(CGAffineTransform(rotationAngle: -0.32))
            let tip = CGPoint(x: 1.08, y: -6.1)
            var stem = Path()
            stem.move(to: CGPoint(x: 1.05, y: -0.28))
            stem.addQuadCurve(to: tip, control: CGPoint(x: 1.18, y: -3.4))
            var flag = Path()
            if kind == 2 || kind == 3 {
                flag.move(to: tip)
                flag.addCurve(to: CGPoint(x: 2.72, y: -3.85),
                              control1: CGPoint(x: 1.25, y: -5.15),
                              control2: CGPoint(x: 3.12, y: -5.10))
                flag.addCurve(to: CGPoint(x: 1.68, y: -2.05),
                              control1: CGPoint(x: 2.96, y: -3.12),
                              control2: CGPoint(x: 2.05, y: -2.58))
                flag.addCurve(to: CGPoint(x: 2.24, y: -3.76),
                              control1: CGPoint(x: 2.03, y: -2.86),
                              control2: CGPoint(x: 2.50, y: -3.21))
                flag.addCurve(to: tip,
                              control1: CGPoint(x: 2.07, y: -4.48),
                              control2: CGPoint(x: 0.94, y: -4.66))
                flag.closeSubpath()
            }
            if kind == 3 {
                // A second swept flag makes a sixteenth note without crowding the stem.
                flag.addPath(flag.applying(CGAffineTransform(translationX: 0, y: 1.05)))
            }
            if kind == 4 {
                let secondHead = head.applying(CGAffineTransform(translationX: 3.6, y: -0.65))
                head.addPath(secondHead)
                stem.move(to: CGPoint(x: 4.65, y: -0.93))
                stem.addQuadCurve(to: CGPoint(x: 4.68, y: -6.75), control: CGPoint(x: 4.78, y: -4.05))
                // A gently sloping, tapered beam joins a pair of eighth notes.
                flag.move(to: CGPoint(x: 1.0, y: -6.12))
                flag.addLine(to: CGPoint(x: 4.72, y: -6.79))
                flag.addLine(to: CGPoint(x: 4.72, y: -6.31))
                flag.addLine(to: CGPoint(x: 1.0, y: -5.72))
                flag.closeSubpath()
            }
            var silhouette = head
            silhouette.addPath(stem)
            silhouette.addPath(flag)
            // A restrained halo, with crisp engraving-like edges rather than a fuzzy music glyph.
            note.stroke(silhouette, with: .color(color.opacity(0.035 + 0.025 * pulse)),
                        style: StrokeStyle(lineWidth: 0.62, lineCap: .round, lineJoin: .round))
            let ink = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [color.opacity(0.45 + 0.10 * pulse),
                                  accent.opacity(0.62 + 0.08 * pulse), color.opacity(0.38)]),
                startPoint: CGPoint(x: -1.2, y: 0.8), endPoint: tip
            )
            if kind == 0 {
                note.stroke(head, with: ink, style: StrokeStyle(lineWidth: 0.19, lineCap: .round))
            } else {
                note.fill(head, with: ink)
            }
            note.stroke(stem, with: ink, style: StrokeStyle(lineWidth: 0.16, lineCap: .round))
            note.fill(flag, with: ink)
            if kind == 5 {
                note.fill(Path(ellipseIn: CGRect(x: 2.0, y: -0.25, width: 0.40, height: 0.40)), with: ink)
            }
        }
    }

    private func musicalTint(phase: Double) -> Color {
        // Similar lightness keeps the pearl/rose/lavender/blue cycle soft instead of flashing.
        Color(red: 0.68 + 0.30 * (0.5 + 0.5 * sin(phase)),
              green: 0.67 + 0.28 * (0.5 + 0.5 * sin(phase + 2.1)),
              blue: 0.72 + 0.27 * (0.5 + 0.5 * sin(phase + 4.2)))
    }

    private func drawCausticFamily(
        in context: inout GraphicsContext,
        size: CGSize,
        time t: Double,
        family: Int,
        count: Int
    ) {
        let steps = 86
        let phaseOffset = Double(family) * 1.73

        for index in 0..<count {
            let p = (Double(index) + 0.5) / Double(count)
            let seed = family * 97 + index * 13
            let drift = 0.5 + 0.5 * sin(t * (0.035 + 0.006 * Double(family)) + p * 5.4)
            let thickness = CGFloat(0.65 + 1.05 * DriftNoise.hash(index, family + 3, seed: seed))
            let brightness = 0.08 + 0.20 * drift
            let color = causticColor(index: index, family: family).opacity(brightness)

            var path = Path()
            for step in 0...steps {
                let u = Double(step) / Double(steps)
                let point = causticPoint(
                    u: u,
                    p: p,
                    size: size,
                    time: t,
                    family: family,
                    seed: seed,
                    phaseOffset: phaseOffset
                )

                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            context.stroke(path, with: .color(color.opacity(0.24)), lineWidth: thickness * 5.0)
            context.stroke(path, with: .color(color.opacity(0.52)), lineWidth: thickness * 2.0)
            context.stroke(path, with: .color(Color.white.opacity(0.08 + 0.05 * drift)), lineWidth: max(0.5, thickness * 0.55))
        }
    }

    private func causticPoint(
        u: Double,
        p: Double,
        size: CGSize,
        time t: Double,
        family: Int,
        seed: Int,
        phaseOffset: Double
    ) -> CGPoint {
        let baseAmplitude = min(size.width, size.height) * CGFloat(0.030 + 0.020 * DriftNoise.hash(family, 4, seed: seed))
        let waveA = sin(u * Double.pi * 2.0 * (1.15 + Double(family) * 0.18) + t * 0.12 + p * 7.0 + phaseOffset)
        let waveB = cos(u * Double.pi * 2.0 * (2.30 + Double(family) * 0.12) - t * 0.075 + p * 4.0)
        let offset = baseAmplitude * CGFloat(waveA + 0.55 * waveB)

        switch family {
        case 0:
            return CGPoint(
                x: size.width * CGFloat(u),
                y: size.height * CGFloat(p) + offset
            )
        case 1:
            return CGPoint(
                x: size.width * CGFloat(p) + offset,
                y: size.height * CGFloat(u)
            )
        default:
            let diagonal = CGFloat(u)
            let sweep = CGFloat(p - 0.5) * size.width * 0.72
            return CGPoint(
                x: size.width * diagonal + sweep + offset,
                y: size.height * CGFloat(1.0 - u) + offset * 0.55
            )
        }
    }

    private func drawGlints(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let glints = min(42, max(18, Int(size.width / 22)))

        for index in 0..<glints {
            let x = size.width * CGFloat(DriftNoise.hash(index, 2, seed: 700))
            let y = size.height * CGFloat(DriftNoise.hash(index, 5, seed: 700))
            let pulse = max(0.0, sin(t * 0.42 + Double(index) * 1.9))
            let radius = CGFloat(1.4 + 4.8 * pulse * DriftNoise.hash(index, 8, seed: 700))
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)

            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.white.opacity(0.16 * pulse),
                        config.palette.secondary.opacity(0.10 * pulse),
                        Color.clear
                    ]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: max(radius, 1)
                )
            )
        }
    }

    private func drawVignette(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.26)
                ]),
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                startRadius: min(size.width, size.height) * 0.20,
                endRadius: max(size.width, size.height) * 0.76
            )
        )
    }

    private func causticColor(index: Int, family: Int) -> Color {
        if index % 11 == 0 { return config.palette.secondary }
        if index % 7 == 0 { return config.palette.tertiary }
        return family == 1 ? config.palette.primary : Color.white
    }

    private func lineCount(for size: CGSize, divisor: CGFloat, minimum: Int, maximum: Int) -> Int {
        min(maximum, max(minimum, Int(max(size.width, size.height) / divisor)))
    }
}

struct ObsidianMonolithView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    render(in: context, size: size, time: t)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func render(in context: GraphicsContext, size: CGSize, time t: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.tertiary.opacity(0.12),
                    config.palette.primary.opacity(0.05),
                    Color.clear
                ]),
                center: CGPoint(x: size.width * 0.54, y: size.height * 0.40),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.85
            )
        )

        var glass = context
        glass.blendMode = .plusLighter

        let count = min(9, max(6, Int(size.width / 170)))
        for index in 0..<count {
            drawPanel(index: index, count: count, in: &glass, size: size, time: t)
        }

        drawFloorReflection(in: &glass, size: size, time: t)
        drawVignette(in: context, size: size)
    }

    private func drawPanel(
        index: Int,
        count: Int,
        in context: inout GraphicsContext,
        size: CGSize,
        time t: Double
    ) {
        let p = Double(index) / Double(max(1, count - 1))
        let depth = 0.72 + 0.28 * DriftNoise.hash(index, 3, seed: 250)
        let panelHeight = size.height * CGFloat(0.58 + 0.28 * depth)
        let panelWidth = size.width * CGFloat(0.085 + 0.045 * DriftNoise.hash(index, 6, seed: 250))
        let centerX = size.width * CGFloat(0.10 + 0.80 * p)
        let driftX = size.width * CGFloat(0.018 * sin(t * 0.045 + Double(index) * 1.27))
        let centerY = size.height * CGFloat(0.48 + 0.035 * cos(t * 0.035 + Double(index)))
        let skew = panelWidth * CGFloat(-0.24 + 0.48 * DriftNoise.hash(index, 9, seed: 250))

        let topY = centerY - panelHeight * 0.52
        let bottomY = centerY + panelHeight * 0.52
        let x = centerX + driftX
        let leftTop = CGPoint(x: x - panelWidth * 0.50 + skew, y: topY)
        let rightTop = CGPoint(x: x + panelWidth * 0.50 + skew * 0.55, y: topY)
        let rightBottom = CGPoint(x: x + panelWidth * 0.62 - skew * 0.22, y: bottomY)
        let leftBottom = CGPoint(x: x - panelWidth * 0.62 - skew * 0.48, y: bottomY)

        var panel = Path()
        panel.move(to: leftTop)
        panel.addLine(to: rightTop)
        panel.addLine(to: rightBottom)
        panel.addLine(to: leftBottom)
        panel.closeSubpath()

        let pulse = 0.5 + 0.5 * sin(t * 0.16 + Double(index) * 0.91)
        let fillOpacity = 0.035 + 0.035 * pulse
        context.fill(
            panel,
            with: .linearGradient(
                Gradient(colors: [
                    config.palette.secondary.opacity(fillOpacity),
                    Color.white.opacity(0.026),
                    config.palette.primary.opacity(fillOpacity * 0.72)
                ]),
                startPoint: leftTop,
                endPoint: rightBottom
            )
        )

        drawInnerLight(
            index: index,
            panel: panel,
            top: CGPoint(x: (leftTop.x + rightTop.x) * 0.5, y: topY),
            bottom: CGPoint(x: (leftBottom.x + rightBottom.x) * 0.5, y: bottomY),
            panelWidth: panelWidth,
            panelHeight: panelHeight,
            in: context,
            time: reduceMotion ? 0 : t
        )

        let edgeColor = index % 3 == 0 ? config.palette.primary : config.palette.secondary
        context.stroke(panel, with: .color(edgeColor.opacity(0.10 + 0.08 * pulse)), lineWidth: 5.5)
        context.stroke(panel, with: .color(Color.white.opacity(0.075 + 0.04 * pulse)), lineWidth: 1.2)

        var leadingEdge = Path()
        leadingEdge.move(to: leftTop)
        leadingEdge.addLine(to: leftBottom)
        context.stroke(leadingEdge, with: .color(config.palette.primary.opacity(0.18 + 0.12 * pulse)), lineWidth: 1.5)

        if index % 2 == 0 {
            var glint = Path()
            let glintX = x + panelWidth * CGFloat(-0.22 + 0.44 * pulse)
            glint.move(to: CGPoint(x: glintX + skew * 0.3, y: topY + panelHeight * 0.12))
            glint.addLine(to: CGPoint(x: glintX - skew * 0.2, y: bottomY - panelHeight * 0.14))
            context.stroke(glint, with: .color(Color.white.opacity(0.08 + 0.08 * pulse)), lineWidth: 1.1)
        }
    }

    /// Each column carries one quiet light, reversing gently rather than resetting at an edge.
    private func drawInnerLight(
        index: Int,
        panel: Path,
        top: CGPoint,
        bottom: CGPoint,
        panelWidth: CGFloat,
        panelHeight: CGFloat,
        in context: GraphicsContext,
        time: Double
    ) {
        let seed = 3100 + index * 17
        let phase = DriftNoise.hash(index, 3, seed: seed) * .pi * 2
        let rate = (0.13 + 0.05 * DriftNoise.hash(index, 5, seed: seed)) * 0.40
        let travel = CGFloat(0.14 + 0.72 * (0.5 - 0.5 * cos(time * rate + phase)))
        let lateral = panelWidth * CGFloat(-0.16 + 0.32 * DriftNoise.hash(index, 7, seed: seed))
        let center = CGPoint(
            x: top.x + (bottom.x - top.x) * travel + lateral,
            y: top.y + (bottom.y - top.y) * travel
        )
        let tint = index % 2 == 0 ? config.palette.primary : config.palette.tertiary
        var light = context
        light.clip(to: panel)

        // Scale the shading with the ellipse so the glow has no hard rectangular cutoff.
        var halo = light
        halo.translateBy(x: center.x, y: center.y)
        halo.scaleBy(x: max(2, panelWidth * 0.46), y: max(8, panelHeight * 0.085))
        halo.fill(
            Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
            with: .radialGradient(
                Gradient(colors: [tint.opacity(0.14), tint.opacity(0.045), Color.clear]),
                center: .zero,
                startRadius: 0,
                endRadius: 1
            )
        )

        let length = max(8, min(25, panelHeight * 0.034))
        var filament = Path()
        filament.move(to: CGPoint(x: center.x, y: center.y - length))
        filament.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y + length),
            control: CGPoint(x: center.x + panelWidth * 0.08, y: center.y)
        )
        light.stroke(
            filament,
            with: .linearGradient(
                Gradient(colors: [Color.clear, tint.opacity(0.24), Color.white.opacity(0.26), tint.opacity(0.16), Color.clear]),
                startPoint: CGPoint(x: center.x, y: center.y - length),
                endPoint: CGPoint(x: center.x, y: center.y + length)
            ),
            style: StrokeStyle(lineWidth: max(1, panelWidth * 0.034), lineCap: .round)
        )
    }

    private func drawFloorReflection(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let center = CGPoint(x: size.width * 0.52, y: size.height * 0.82)
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - size.width * 0.36,
                y: center.y - size.height * 0.06,
                width: size.width * 0.72,
                height: size.height * 0.12
            )),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.primary.opacity(0.10 + 0.04 * sin(t * 0.08)),
                    config.palette.secondary.opacity(0.05),
                    Color.clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: size.width * 0.38
            )
        )
    }

    private func drawVignette(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.34)
                ]),
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                startRadius: min(size.width, size.height) * 0.18,
                endRadius: max(size.width, size.height) * 0.78
            )
        )
    }
}

struct LumenVaultView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed
    @Environment(\.driftAnimationsPaused) private var animationsPaused

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed)

            GeometryReader { proxy in
                let size = proxy.size

                Canvas { context, _ in
                    render(in: context, size: size, time: t)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func render(in context: GraphicsContext, size: CGSize, time t: Double) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    config.palette.backgroundTop,
                    config.palette.backgroundBottom
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        drawLightShafts(in: context, size: size, time: t)

        var glow = context
        glow.blendMode = .plusLighter
        drawVaultArches(in: &glow, size: size, time: t)
        drawApertureGlow(in: &glow, size: size, time: t)
        drawVignette(in: context, size: size)
    }

    private func drawLightShafts(in context: GraphicsContext, size: CGSize, time t: Double) {
        let count = 5
        for index in 0..<count {
            let p = Double(index) / Double(max(1, count - 1))
            let phase = t * 0.035 + p * 2.4
            let centerX = size.width * CGFloat(0.22 + 0.56 * p + 0.035 * sin(phase))
            let topWidth = size.width * CGFloat(0.04 + 0.02 * DriftNoise.hash(index, 4, seed: 900))
            let bottomWidth = size.width * CGFloat(0.18 + 0.06 * DriftNoise.hash(index, 6, seed: 900))

            var shaft = Path()
            shaft.move(to: CGPoint(x: centerX - topWidth, y: 0))
            shaft.addLine(to: CGPoint(x: centerX + topWidth, y: 0))
            shaft.addLine(to: CGPoint(x: centerX + bottomWidth, y: size.height))
            shaft.addLine(to: CGPoint(x: centerX - bottomWidth, y: size.height))
            shaft.closeSubpath()

            context.fill(
                shaft,
                with: .linearGradient(
                    Gradient(colors: [
                        config.palette.primary.opacity(0.06),
                        config.palette.secondary.opacity(0.018),
                        Color.clear
                    ]),
                    startPoint: CGPoint(x: centerX, y: 0),
                    endPoint: CGPoint(x: centerX, y: size.height)
                )
            )
        }
    }

    private func drawVaultArches(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let archCount = min(14, max(8, Int(size.height / 86)))
        let centerX = size.width * 0.5
        let bottomY = size.height * 0.88

        for index in 0..<archCount {
            let p = Double(index) / Double(max(1, archCount - 1))
            let width = size.width * CGFloat(0.24 + 0.74 * p)
            let height = size.height * CGFloat(0.18 + 0.54 * p)
            let lift = size.height * CGFloat(0.024 * sin(t * 0.065 + p * 4.0))
            let arch = archPath(
                centerX: centerX,
                bottomY: bottomY + lift,
                width: width,
                height: height
            )

            let shimmer = 0.5 + 0.5 * sin(t * 0.14 + p * 5.6)
            let color = index % 3 == 0 ? config.palette.primary : (index % 3 == 1 ? config.palette.secondary : config.palette.tertiary)

            context.stroke(arch, with: .color(color.opacity(0.09 + 0.06 * shimmer)), lineWidth: 8.0)
            context.stroke(arch, with: .color(color.opacity(0.18 + 0.08 * shimmer)), lineWidth: 2.4)
            context.stroke(arch, with: .color(Color.white.opacity(0.07 + 0.05 * shimmer)), lineWidth: 0.9)
        }
    }

    private func drawApertureGlow(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let center = CGPoint(
            x: size.width * (0.50 + 0.03 * sin(t * 0.045)),
            y: size.height * (0.34 + 0.025 * cos(t * 0.05))
        )
        let radius = min(size.width, size.height) * CGFloat(0.12 + 0.018 * sin(t * 0.09))

        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    config.palette.primary.opacity(0.20),
                    config.palette.secondary.opacity(0.08),
                    Color.clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    private func archPath(centerX: CGFloat, bottomY: CGFloat, width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let left = CGPoint(x: centerX - width * 0.5, y: bottomY)
        let right = CGPoint(x: centerX + width * 0.5, y: bottomY)
        let apex = CGPoint(x: centerX, y: bottomY - height)

        path.move(to: left)
        path.addCurve(
            to: apex,
            control1: CGPoint(x: left.x, y: bottomY - height * 0.50),
            control2: CGPoint(x: centerX - width * 0.28, y: apex.y)
        )
        path.addCurve(
            to: right,
            control1: CGPoint(x: centerX + width * 0.28, y: apex.y),
            control2: CGPoint(x: right.x, y: bottomY - height * 0.50)
        )
        return path
    }

    private func drawVignette(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.30)
                ]),
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.48),
                startRadius: min(size.width, size.height) * 0.22,
                endRadius: max(size.width, size.height) * 0.82
            )
        )
    }
}
