import SwiftUI
import Combine
import os

struct DriftLiquidLampView: View {
    let palette: DriftPalette
    let blobCount: Int
    let blur: CGFloat
    let energy: Double
    let speed: Double
    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @StateObject private var cache = LampRendererCache()
    @State private var frameGate = FrameGate(maxFPS: 60)

    var body: some View {
        PausableTimelineView(paused: animationsPaused) { date in
            let t = date.timeIntervalSinceReferenceDate * max(0.25, speed) * 0.18
            
            Canvas { context, size in
#if DEBUG
                let interval = DebugMetrics.renderSignposter.beginInterval("render.frame")
                defer { DebugMetrics.renderSignposter.endInterval("render.frame", interval) }
#endif
                let now = CACurrentMediaTime()
                guard frameGate.shouldCommit(now: now) else { return }
                cache.configureIfNeeded(palette: palette, blobCount: blobCount, overlayRadius: 520, blur: blur, size: size)

                if let background = cache.background {
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: background)
                }

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: blur))
                    layer.blendMode = .screen
                    layer.opacity = 0.95

                    for seed in cache.blobSeeds {
                        let blob = cache.blob(for: seed, time: t, size: size, energy: energy)
                        let shading = GraphicsContext.Shading.radialGradient(
                            cache.blobGradient(for: seed),
                            center: blob.center,
                            startRadius: 0,
                            endRadius: blob.shadingRadius
                        )
                        let rect = CGRect(
                            x: blob.center.x - blob.radius,
                            y: blob.center.y - blob.radius,
                            width: blob.radius * 2,
                            height: blob.radius * 2
                        )
                        layer.fill(Path(ellipseIn: rect), with: shading)
                    }
                }

                if let overlay = cache.overlayWash {
                    context.drawLayer { layer in
                        layer.blendMode = .overlay
                        layer.fill(Path(CGRect(origin: .zero, size: size)), with: overlay)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
}

@MainActor
private final class LampRendererCache: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    struct BlobSeed {
        let phase: Double
        let freqX: Double
        let freqY: Double
        let wobbleFreq: Double
        let wobblePhase: Double
        let sizeBase: Double
        let sizePulseFreq: Double
        let xScale: Double
        let yScale: Double
        let gradient: Gradient
    }

    struct BlobOutput {
        let center: CGPoint
        let radius: CGFloat
        let shadingRadius: CGFloat
    }

    private(set) var background: GraphicsContext.Shading?
    private(set) var overlayWash: GraphicsContext.Shading?
    private(set) var blobSeeds: [BlobSeed] = []

    private var cachedPalette: DriftPalette?
    private var cachedBlobCount: Int = 0
    private var cachedSize: CGSize = .zero
    private var cachedOverlayRadius: CGFloat = 0

    #if DEBUG
    private var rebuildCount: Int = 0
    private let diagnosticsEnabled = false
    #endif

    func configureIfNeeded(palette: DriftPalette, blobCount: Int, overlayRadius: CGFloat, blur: CGFloat, size: CGSize) {
        if cachedSize != size || cachedPalette == nil {
            cachedSize = size
            background = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [palette.backgroundTop, palette.backgroundBottom]),
                startPoint: CGPoint(x: size.width * 0.5, y: 0),
                endPoint: CGPoint(x: size.width * 0.5, y: size.height)
            )
            cachedOverlayRadius = overlayRadius
            overlayWash = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.00)
                ]),
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                startRadius: 0,
                endRadius: overlayRadius
            )
            cachedPalette = palette
            DebugMetrics.incrementCacheRebuild()
        }

        if cachedBlobCount != blobCount || cachedPalette?.primary != palette.primary {
            cachedBlobCount = blobCount
            cachedPalette = palette
            blobSeeds = (0..<blobCount).map { i in
                let phase = Double(i) * 1.7
                let freqX = 0.6 + 0.04 * Double(i)
                let freqY = 0.55 + 0.03 * Double(i)
                let wobbleFreq = 0.9
                let wobblePhase = phase * 0.7

                let base = 260.0 + 42.0 * Double(i % 3)
                let sizePulseFreq = 0.7
                let xScale = 0.28
                let yScale = 0.24

                let color: Color
                switch i % 3 {
                case 0: color = palette.primary
                case 1: color = palette.secondary
                default: color = palette.tertiary
                }

                let gradient = Gradient(colors: [
                    color.opacity(0.95),
                    color.opacity(0.15),
                    Color.clear
                ])

                return BlobSeed(
                    phase: phase,
                    freqX: freqX,
                    freqY: freqY,
                    wobbleFreq: wobbleFreq,
                    wobblePhase: wobblePhase,
                    sizeBase: base,
                    sizePulseFreq: sizePulseFreq,
                    xScale: xScale,
                    yScale: yScale,
                    gradient: gradient
                )
            }
            #if DEBUG
            if diagnosticsEnabled {
                rebuildCount += 1
                DebugMetrics.incrementCacheRebuild()
                print("LampRendererCache rebuilt blobs: \(rebuildCount)")
            }
            #endif
        }
    }

    func blob(for seed: BlobSeed, time: Double, size: CGSize, energy: Double) -> BlobOutput {
        let wobble = (sin(time + seed.phase) + cos(time * seed.wobbleFreq + seed.wobblePhase)) * 0.5

        let x = 0.5 + seed.xScale * sin(time * seed.freqX + seed.phase)
        let y = 0.5 + seed.yScale * cos(time * seed.freqY + seed.phase * 1.1)

        let blobSize = seed.sizeBase * (0.86 + 0.18 * (0.5 + 0.5 * sin(time * seed.sizePulseFreq + seed.phase)))
        let scale = 0.85 + 0.25 * energy * (0.5 + 0.5 * wobble)

        let finalSize = blobSize * scale
        let radius = CGFloat(finalSize * 0.5)
        let shadingRadius = CGFloat(finalSize * 0.62)

        let center = CGPoint(x: CGFloat(x) * size.width, y: CGFloat(y) * size.height)
        return BlobOutput(center: center, radius: radius, shadingRadius: shadingRadius)
    }

    func blobGradient(for seed: BlobSeed) -> Gradient {
        seed.gradient
    }
}
