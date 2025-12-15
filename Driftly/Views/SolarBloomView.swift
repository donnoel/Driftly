import SwiftUI

struct SolarBloomView: View {
    let config: DriftModeConfig
    @Environment(\.driftAnimationSpeed) private var speed

    var body: some View {
        BanksyBloomStencilView(config: config, speed: speed)
            .ignoresSafeArea()
    }
}

// MARK: - Banksy-inspired stencil / street-art solar bloom

private struct BanksyBloomStencilView: View {
    let config: DriftModeConfig
    let speed: Double

    var body: some View {
        TimelineView(.animation) { timeline in
            let raw = timeline.date.timeIntervalSinceReferenceDate
            let t = raw * max(0.25, speed) * 0.14

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: size.width * 0.52, y: size.height * 0.48)

                // Concrete-paper backdrop (brighter, matte, slightly dirty)
                context.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [
                        config.palette.backgroundTop.opacity(1.0),
                        config.palette.backgroundBottom.opacity(0.97)
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))

                // Grain / dust (cheap and effective texture)
                let grainCount = Int((size.width * size.height / 22_000).clamped(to: 120...520))
                for i in 0..<grainCount {
                    let rx = hash01(i, 71)
                    let ry = hash01(i, 97)
                    let r2 = hash01(i, 131)
                    let x = CGFloat(rx) * size.width
                    let y = CGFloat(ry) * size.height
                    let a = 0.010 + 0.020 * r2
                    let s = 0.6 + 1.4 * r2
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                        with: .color(Color.black.opacity(a))
                    )
                }

                // Paper-paste / torn poster edges (subtle, makes it feel like a wall piece)
                drawPaste(in: &context, size: size, t: t)

                // A soft, off-register shadow to feel like sprayed stencil
                let jitter = CGPoint(
                    x: CGFloat(2.0 * sin(t * 0.35)) + CGFloat(1.0 * cos(t * 0.21)),
                    y: CGFloat(1.5 * cos(t * 0.31))
                )

                // Main stencil shapes
                let black = Color.black.opacity(0.92)
                let accentRed = Color(red: 1.00, green: 0.06, blue: 0.14) // bright red

                // Pulse: makes the "sun" feel alive (subtle)
                let pulse = 0.5 + 0.5 * sin(t * 0.75)
                let sunR = min(size.width, size.height) * (0.17 + 0.02 * CGFloat(pulse))

                // Draw shadow layer first
                drawStencil(in: &context,
                            center: CGPoint(x: center.x + jitter.x * 1.2, y: center.y + jitter.y * 1.2),
                            sunRadius: sunR,
                            ink: Color.black.opacity(0.14),
                            accent: accentRed.opacity(0.10),
                            t: t,
                            size: size,
                            isShadow: true)

                // Off-register halftone haze behind the main stencil (adds depth)
                drawHalftoneHaze(in: &context, center: center, t: t, size: size, color: accentRed)

                // Ghost stencil (faint underlayer that drifts in/out)
                let ghostFade = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 0.085))
                let ghostOffset = CGPoint(
                    x: CGFloat(18.0 * sin(t * 0.06) + 10.0 * cos(t * 0.04)),
                    y: CGFloat(-14.0 * cos(t * 0.05) + 8.0 * sin(t * 0.03))
                )
                drawStencil(in: &context,
                            center: CGPoint(x: center.x + ghostOffset.x, y: center.y + ghostOffset.y),
                            sunRadius: sunR * 1.06,
                            ink: config.palette.tertiary.opacity(0.10 * ghostFade),
                            accent: accentRed.opacity(0.08 * ghostFade),
                            t: t,
                            size: size,
                            isShadow: false)

                // Draw main layer
                drawStencil(in: &context,
                            center: center,
                            sunRadius: sunR,
                            ink: black,
                            accent: accentRed,
                            t: t,
                            size: size,
                            isShadow: false)

                // Stencil registration marks (tiny, iconic)
                drawRegistrationMarks(in: &context, center: center, t: t, size: size)

                // Soft overspray mist around the sun (very subtle)
                drawOverspray(in: &context, center: center, sunRadius: sunR, t: t)

                // Animated sweep (like a gallery light catching wet paint)
                let sweepX = center.x + CGFloat(sin(t * 0.10)) * size.width * 0.42
                let sweepRect = CGRect(x: sweepX - 180, y: 0, width: 360, height: size.height)
                context.fill(
                    Path(sweepRect),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.00),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.00)
                        ]),
                        startPoint: CGPoint(x: sweepRect.minX, y: 0),
                        endPoint: CGPoint(x: sweepRect.maxX, y: 0)
                    )
                )
            }
        }
    }

    private func drawStencil(
        in context: inout GraphicsContext,
        center: CGPoint,
        sunRadius: CGFloat,
        ink: Color,
        accent: Color,
        t: Double,
        size: CGSize,
        isShadow: Bool
    ) {
        // Sun disk
        let sunRect = CGRect(x: center.x - sunRadius, y: center.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2)
        let sunPath = Path(ellipseIn: sunRect)

        // Rays (stencil-ish: thick bars)
        var rays = Path()
        let rayCount = 12
        let rayLen = sunRadius * 1.85
        let rayW = sunRadius * 0.22

        for i in 0..<rayCount {
            let a = Double(i) / Double(rayCount) * Double.pi * 2.0
            let wob = 0.06 * sin(t * 0.22 + Double(i) * 0.8)
            let ang = a + wob

            let dx = CGFloat(cos(ang))
            let dy = CGFloat(sin(ang))

            // Bar centered on the direction
            let start = CGPoint(x: center.x + dx * (sunRadius * 1.05), y: center.y + dy * (sunRadius * 1.05))
            let end = CGPoint(x: center.x + dx * rayLen, y: center.y + dy * rayLen)

            // Perpendicular
            let px = -dy
            let py = dx

            let p1 = CGPoint(x: start.x + px * (rayW * 0.5), y: start.y + py * (rayW * 0.5))
            let p2 = CGPoint(x: start.x - px * (rayW * 0.5), y: start.y - py * (rayW * 0.5))
            let p3 = CGPoint(x: end.x - px * (rayW * 0.35), y: end.y - py * (rayW * 0.35))
            let p4 = CGPoint(x: end.x + px * (rayW * 0.35), y: end.y + py * (rayW * 0.35))

            var bar = Path()
            bar.move(to: p1)
            bar.addLine(to: p2)
            bar.addLine(to: p3)
            bar.addLine(to: p4)
            bar.closeSubpath()
            if i == 2 {
                // Heartbeat pulse on a single ray
                let beat = heartbeat(t * 0.85)

                // Scale around the bar midpoint
                let mx = (start.x + end.x) * 0.5
                let my = (start.y + end.y) * 0.5

                var tp = CGAffineTransform.identity
                tp = tp.translatedBy(x: mx, y: my)
                tp = tp.scaledBy(x: 1.0 + 0.06 * beat, y: 1.0 + 0.16 * beat)
                tp = tp.translatedBy(x: -mx, y: -my)

                rays.addPath(bar.applying(tp))
            } else {
                rays.addPath(bar)
            }
        }

        // Stencil cutouts (negative holes in the sun)
        var cutouts = Path()
        var cutoutAnchors: [(CGPoint, CGFloat)] = []
        var cutoutRects: [(CGRect, CGFloat)] = []
        let holeCount = isShadow ? 5 : 7
        for i in 0..<holeCount {
            let r = sunRadius * (0.10 + 0.08 * CGFloat(hash01(i, 401)))
            let ang = Double(hash01(i, 433)) * Double.pi * 2.0
            let rr = sunRadius * (0.15 + 0.35 * CGFloat(hash01(i, 467)))
            let cx = center.x + CGFloat(cos(ang)) * rr
            let cy = center.y + CGFloat(sin(ang)) * rr
            let sx = 0.75 + 0.70 * CGFloat(hash01(i, 481))
            let sy = 0.75 + 0.70 * CGFloat(hash01(i, 509))
            let w = r * 2 * sx
            let h = r * 2 * sy
            let cRect = CGRect(x: cx - w * 0.5, y: cy - h * 0.5, width: w, height: h)
            let cCorner = min(w, h) * 0.42
            cutouts.addPath(Path(roundedRect: cRect, cornerRadius: cCorner))
            cutoutRects.append((cRect, cCorner))
            cutoutAnchors.append((CGPoint(x: cx, y: cy + h * 0.5), max(w, h)))
        }

        // Fill rays + sun
        context.fill(rays, with: .color(ink))
        context.fill(sunPath, with: .color(ink))

        // Punch holes by overdrawing with background-ish color (stencil feel)
        let erasePulse = 0.5 + 0.5 * sin(t * 0.12)
        let erase = Color.white.opacity(isShadow ? (0.48 + 0.06 * erasePulse) : (0.86 + 0.06 * erasePulse))
        context.fill(cutouts, with: .color(erase))

        // Red eyeball in the top-right cutout (main layer only)
        if !isShadow, !cutoutRects.isEmpty {
            // Pick the cutout with the highest X and lowest Y (top-right)
            var best = 0
            var bestScore = -Double.greatestFiniteMagnitude
            for i in 0..<cutoutRects.count {
                let r = cutoutRects[i].0
                let score = Double(r.midX) - 1.35 * Double(r.midY)
                if score > bestScore {
                    bestScore = score
                    best = i
                }
            }

            let (blobRect, blobCorner) = cutoutRects[best]

            // Eyeball geometry inside the blob
            let inset = min(blobRect.width, blobRect.height) * 0.12
            let eyeRect = blobRect.insetBy(dx: inset, dy: inset)

            // Subtle pulse so it feels alive
            let eyePulse = 0.5 + 0.5 * sin(t * 0.28)
            let irisScale = CGFloat(0.72 + 0.10 * eyePulse)
            let pupilScale = CGFloat(0.28 + 0.06 * (1.0 - eyePulse))

            let cx = eyeRect.midX
            let cy = eyeRect.midY
            let irisR = min(eyeRect.width, eyeRect.height) * 0.5 * irisScale
            let pupilR = irisR * pupilScale

            let red = Color(red: 1.00, green: 0.00, blue: 0.12)

            // A faint shadow at the bottom of the blob for depth
            let shade = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Color.black.opacity(0.00), Color.black.opacity(0.12)]),
                startPoint: CGPoint(x: 0, y: eyeRect.minY),
                endPoint: CGPoint(x: 0, y: eyeRect.maxY)
            )
            context.fill(Path(roundedRect: blobRect, cornerRadius: blobCorner), with: shade)

            // Iris glow
            let irisGlowRect = CGRect(x: cx - irisR * 1.35, y: cy - irisR * 1.35, width: irisR * 2.7, height: irisR * 2.7)
            context.fill(Path(ellipseIn: irisGlowRect), with: .radialGradient(
                Gradient(colors: [red.opacity(0.18), red.opacity(0.00)]),
                center: CGPoint(x: cx, y: cy),
                startRadius: 0,
                endRadius: irisR * 1.35
            ))

            // Iris
            let irisRect = CGRect(x: cx - irisR, y: cy - irisR, width: irisR * 2, height: irisR * 2)
            context.fill(Path(ellipseIn: irisRect), with: .color(red.opacity(0.90)))
            context.stroke(Path(ellipseIn: irisRect), with: .color(Color.white.opacity(0.10)), lineWidth: 1.0)

            // Pupil
            let pupilRect = CGRect(x: cx - pupilR, y: cy - pupilR, width: pupilR * 2, height: pupilR * 2)
            context.fill(Path(ellipseIn: pupilRect), with: .color(Color.black.opacity(0.92)))

            // Specular highlight
            let hR = pupilR * 0.55
            let hx = cx - irisR * 0.22
            let hy = cy - irisR * 0.28
            context.fill(Path(ellipseIn: CGRect(x: hx - hR, y: hy - hR, width: hR * 2, height: hR * 2)),
                         with: .color(Color.white.opacity(0.22)))
        }

        // Paint drips from the cutout holes (feels like wet stencil ink)
        if !cutoutAnchors.isEmpty {
            let dripInk = Color.white.opacity(isShadow ? 0.10 : 0.18)
            let dripCount = isShadow ? 3 : 6

            for j in 0..<min(dripCount, cutoutAnchors.count) {
                let (p0, sz) = cutoutAnchors[j]
                let pick = Int(floor(hash01(j, isShadow ? 9801 : 9901) * Double(cutoutAnchors.count)))
                let (p, szz) = cutoutAnchors[max(0, min(cutoutAnchors.count - 1, pick))]

                let baseW = max(2.0, min(5.0, (szz * 0.10)))
                let baseLen = (isShadow ? 0.32 : 0.55) * szz * (0.55 + 0.70 * CGFloat(hash01(j, 9929)))

                // Gentle animated wobble so drips feel alive
                let wob = CGFloat(2.0 * sin(t * (0.20 + 0.03 * Double(j)) + Double(j) * 1.7))
                let pulse = CGFloat(0.5 + 0.5 * sin(t * 0.18 + Double(j) * 0.9))
                let len = baseLen * (0.90 + 0.20 * pulse)

                // One drip can split into a tiny twin (occasional)
                let split = hash01(j, 9967) > 0.72
                let splits = split ? 2 : 1

                for s in 0..<splits {
                    let dx = wob + (split ? (CGFloat(s) == 0 ? -2.0 : 2.0) : 0.0)
                    let w = baseW * (split ? 0.85 : 1.0)

                    let dripRect = CGRect(
                        x: p.x - w * 0.5 + dx,
                        y: p.y + 3.0,
                        width: w,
                        height: len
                    )

                    // Drip tip (rounded drop)
                    let tip = Path(ellipseIn: CGRect(x: dripRect.midX - (w * 0.85),
                                                    y: dripRect.maxY - (w * 1.2),
                                                    width: w * 1.7,
                                                    height: w * 2.0))

                    context.fill(Path(roundedRect: dripRect, cornerRadius: w * 0.55), with: .color(dripInk.opacity(isShadow ? 0.55 : 0.80)))
                    context.fill(tip, with: .color(dripInk.opacity(isShadow ? 0.45 : 0.75)))

                    // Soft glow edge so it reads over dark ink
                    context.stroke(Path(roundedRect: dripRect, cornerRadius: w * 0.55),
                                   with: .color(Color.white.opacity(isShadow ? 0.05 : 0.08)),
                                   lineWidth: 0.9)
                }
            }
        }

        // Red tag accent: a rough underline / swipe
        if !isShadow {
            let tagPulse = 0.5 + 0.5 * sin(t * 0.72)
            let tagY = center.y + sunRadius * 1.55
            var tag = Path()
            let tagW = sunRadius * 2.2
            let tagH: CGFloat = 9 + 7 * CGFloat(tagPulse)
            let x0 = center.x - tagW * 0.55
            let x1 = center.x + tagW * 0.55

            // Wobbly stripe
            tag.move(to: CGPoint(x: x0, y: tagY))
            let steps = 18
            for s in 0...steps {
                let u = CGFloat(s) / CGFloat(steps)
                let x = x0 + (x1 - x0) * u
                let w = 5 * sin(Double(u) * 10.0 + t * 0.9) + 3 * cos(Double(u) * 7.0 + t * 0.6)
                tag.addLine(to: CGPoint(x: x, y: tagY + CGFloat(w)))
            }
            for s in stride(from: steps, through: 0, by: -1) {
                let u = CGFloat(s) / CGFloat(steps)
                let x = x0 + (x1 - x0) * u
                let w = 5 * sin(Double(u) * 10.0 + t * 0.9) + 3 * cos(Double(u) * 7.0 + t * 0.6)
                tag.addLine(to: CGPoint(x: x, y: tagY + tagH + CGFloat(w) * 0.35))
            }
            tag.closeSubpath()

            context.fill(tag, with: .color(accent.opacity(0.72 + 0.22 * Double(tagPulse))))
            context.stroke(tag, with: .color(Color.white.opacity(0.10 + 0.06 * Double(tagPulse))), lineWidth: 1.0)
        }

        // Drips (spray paint gravity)
        let dripCount = isShadow ? 8 : 12
        for i in 0..<dripCount {
            let r = hash01(i, 601)
            let x = center.x + (CGFloat(r) - 0.5) * sunRadius * 2.2
            let y0 = center.y + sunRadius * 0.85
            let len = sunRadius * (0.25 + 0.90 * CGFloat(hash01(i, 631)))

            let wob = CGFloat(2.0 * sin(t * (0.22 + 0.03 * Double(i)) + Double(i)))
            let drift = CGFloat(6.0 * (0.5 + 0.5 * sin(t * 0.08 + Double(i) * 0.7)))

            let path = Path(roundedRect: CGRect(x: x + wob, y: y0 + drift, width: 3.0, height: len), cornerRadius: 1.5)
            context.fill(path, with: .color(ink.opacity(isShadow ? 0.35 : 0.62)))
        }

        // Splatter (a few dots, animated drift)
        let splatCount = isShadow ? 40 : 70
        for i in 0..<splatCount {
            let rx = hash01(i, 701)
            let ry = hash01(i, 733)
            let rr = hash01(i, 769)

            let px = center.x + (CGFloat(rx) - 0.5) * sunRadius * 5.0
            let py = center.y + (CGFloat(ry) - 0.5) * sunRadius * 5.0
            let s = 0.8 + 2.4 * rr

            let driftX = CGFloat(4.0 * sin(t * 0.05 + Double(i) * 0.9))
            let driftY = CGFloat(3.0 * cos(t * 0.04 + Double(i) * 0.7))

            let a = (isShadow ? 0.06 : 0.10) + (isShadow ? 0.06 : 0.14) * rr
            context.fill(
                Path(ellipseIn: CGRect(x: px + driftX, y: py + driftY, width: s, height: s)),
                with: .color(ink.opacity(a))
            )
        }
    }

    // MARK: - Wall texture helpers

    private func drawPaste(in context: inout GraphicsContext, size: CGSize, t: Double) {
        // Two faint pasted rectangles with torn-ish edges
        let w = size.width
        let h = size.height
        let paperA = Color.white.opacity(0.10)
        let paperB = Color.white.opacity(0.07)

        let r1 = 0.5 + 0.5 * sin(t * 0.06)
        let r2 = 0.5 + 0.5 * cos(t * 0.05)

        let rect1 = CGRect(x: w * (0.10 + 0.02 * r1), y: h * (0.14 + 0.02 * r2), width: w * 0.78, height: h * 0.68)
        let rect2 = CGRect(x: w * (0.16 - 0.02 * r2), y: h * (0.20 - 0.02 * r1), width: w * 0.72, height: h * 0.60)

        context.fill(tornRect(rect1, t: t, seed: 9001), with: .color(paperA))
        context.fill(tornRect(rect2, t: t, seed: 9002), with: .color(paperB))

        // Slight grime along the bottom edge
        let grime = Path(roundedRect: CGRect(x: 0, y: h * 0.82, width: w, height: h * 0.18), cornerRadius: 28)
        context.fill(grime, with: .linearGradient(
            Gradient(colors: [Color.black.opacity(0.00), Color.black.opacity(0.08)]),
            startPoint: CGPoint(x: 0, y: h * 0.82),
            endPoint: CGPoint(x: 0, y: h)
        ))
    }

    private func tornRect(_ rect: CGRect, t: Double, seed: Int) -> Path {
        // A cheap torn edge: jitter the corners and add small bites
        let biteCount = 10
        var p = Path()
        let inset = 8.0
        let r = rect.insetBy(dx: inset, dy: inset)

        func jitter(_ v: CGFloat, _ s: Int) -> CGFloat {
            let j = (hash01(s, seed) - 0.5)
            return v + CGFloat(j) * 10.0
        }

        let c1 = CGPoint(x: jitter(r.minX, 1), y: jitter(r.minY, 2))
        let c2 = CGPoint(x: jitter(r.maxX, 3), y: jitter(r.minY, 4))
        let c3 = CGPoint(x: jitter(r.maxX, 5), y: jitter(r.maxY, 6))
        let c4 = CGPoint(x: jitter(r.minX, 7), y: jitter(r.maxY, 8))

        p.move(to: c1)
        p.addLine(to: c2)
        p.addLine(to: c3)
        p.addLine(to: c4)
        p.closeSubpath()

        // Little edge bites
        for i in 0..<biteCount {
            let u = Double(i) / Double(max(1, biteCount - 1))
            let x = r.minX + CGFloat(u) * r.width
            let y = r.minY + CGFloat(3.0 + 4.0 * sin(t * 0.07 + u * 6.0))
            let rad = CGFloat(5.0 + 8.0 * hash01(i, seed + 77))
            p.addPath(Path(ellipseIn: CGRect(x: x - rad * 0.5, y: y - rad * 0.5, width: rad, height: rad)))
        }

        return p
    }

    private func drawRegistrationMarks(in context: inout GraphicsContext, center: CGPoint, t: Double, size: CGSize) {
        // Tiny crosshair marks like stencil alignment
        let ink = Color.black.opacity(0.38)
        let w: CGFloat = 16
        let gap: CGFloat = 4

        let pts = [
            CGPoint(x: center.x - size.width * 0.24, y: center.y - size.height * 0.22),
            CGPoint(x: center.x + size.width * 0.26, y: center.y - size.height * 0.18),
            CGPoint(x: center.x - size.width * 0.22, y: center.y + size.height * 0.26)
        ]

        let drift = CGFloat(0.6 * sin(t * 0.08))

        for p0 in pts {
            let p = CGPoint(x: p0.x + drift, y: p0.y - drift)
            var cross = Path()
            cross.move(to: CGPoint(x: p.x - w, y: p.y))
            cross.addLine(to: CGPoint(x: p.x - gap, y: p.y))
            cross.move(to: CGPoint(x: p.x + gap, y: p.y))
            cross.addLine(to: CGPoint(x: p.x + w, y: p.y))
            cross.move(to: CGPoint(x: p.x, y: p.y - w))
            cross.addLine(to: CGPoint(x: p.x, y: p.y - gap))
            cross.move(to: CGPoint(x: p.x, y: p.y + gap))
            cross.addLine(to: CGPoint(x: p.x, y: p.y + w))

            context.stroke(cross, with: .color(ink), lineWidth: 1.2)
            context.stroke(cross, with: .color(Color.white.opacity(0.06)), lineWidth: 0.7)
        }
    }

    private func drawHalftoneHaze(in context: inout GraphicsContext, center: CGPoint, t: Double, size: CGSize, color: Color) {
        // Halftone dot field behind the sun (subtle, slow drift)
        let count = Int((size.width * size.height / 30_000).clamped(to: 90...260))
        let maxR = min(size.width, size.height) * 0.42

        for i in 0..<count {
            let a = Double(i) * 0.42
            let r = maxR * CGFloat(hash01(i, 1201))
            let ang = Double(hash01(i, 1229)) * Double.pi * 2

            let dx = CGFloat(cos(ang)) * r
            let dy = CGFloat(sin(ang)) * r

            let driftX = CGFloat(10.0 * sin(t * 0.05 + a))
            let driftY = CGFloat(8.0 * cos(t * 0.04 + a))

            let s = 0.8 + 3.0 * hash01(i, 1259)
            let p = CGPoint(x: center.x + dx + driftX, y: center.y + dy + driftY)

            let falloff = max(0.0, 1.0 - Double((abs(dx) + abs(dy)) / (maxR * 1.25)))
            let op = (0.02 + 0.06 * falloff) * (0.6 + 0.4 * hash01(i, 1291))

            context.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: s, height: s)), with: .color(color.opacity(op)))
        }
    }

    private func drawOverspray(in context: inout GraphicsContext, center: CGPoint, sunRadius: CGFloat, t: Double) {
        // A faint mist ring: helps sell spray paint without adding UI noise
        let r = sunRadius * 2.25
        let pulse = 0.5 + 0.5 * sin(t * 0.22)
        let mist = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [
                Color.black.opacity(0.00),
                Color.black.opacity(0.06 + 0.03 * pulse),
                Color.black.opacity(0.00)
            ]),
            center: center,
            startRadius: sunRadius * 1.10,
            endRadius: r
        )

        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: rect), with: mist)
    }

    // MARK: - Helpers

    private func heartbeat(_ x: Double) -> CGFloat {
        // Two-lobed beat per cycle: lub-dub
        let f = x - floor(x)

        func bump(_ u: Double, center: Double, width: Double) -> Double {
            let d = abs(u - center) / width
            if d >= 1 { return 0 }
            // Smooth bell-ish curve
            let v = 1.0 - d
            return v * v * (3.0 - 2.0 * v)
        }

        let lub = bump(f, center: 0.12, width: 0.10)
        let dub = 0.75 * bump(f, center: 0.34, width: 0.08)
        return CGFloat(min(1.0, lub + dub))
    }

    private func hash01(_ x: Int, _ seed: Int) -> Double {
        var n = x &* 374761393 &+ seed &* 668265263
        n = (n ^ (n >> 13)) &* 1274126177
        return Double(n & 0x7fffffff) / 2147483647.0
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
