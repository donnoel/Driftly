import SwiftUI
import UIKit

struct ClockStyle {
    let font: Font
    let color: Color
    let tracking: CGFloat
}

struct ClockOverlayView: View {
    let time: Date
    let style: ClockStyle
    let anchorDate: Date
    let containerSize: CGSize

    @Environment(\.driftAnimationsPaused) private var animationsPaused
    @State private var targetPosition: CGPoint = .zero
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1
    @State private var moveWork: DispatchWorkItem?

    private static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .autoupdatingCurrent
        if let format = DateFormatter.dateFormat(fromTemplate: "j:mm", options: 0, locale: df.locale) {
            df.dateFormat = format
        } else {
            df.timeStyle = .short
        }
        return df
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 60.0)) { timeline in
            let raw = animationsPaused ? 0 : timeline.date.timeIntervalSince(anchorDate)
            let beat = 0.5 + 0.5 * sin(raw * 1.3)
            let pulseScale = 1.0 + 0.05 * beat
            let glow = style.color.opacity(0.22 + 0.10 * beat)

            Text(Self.formatter.string(from: time))
                .font(style.font)
                .foregroundStyle(style.color.opacity(0.82))
                .tracking(style.tracking)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )
                .scaleEffect(pulseScale * scale)
                .opacity(opacity * 0.84)
                .shadow(color: glow.opacity(0.32), radius: 10 + 2 * beat, x: 0, y: 5)
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 4)
                .position(currentPosition)
                .accessibilityLabel("Current time \(Self.formatter.string(from: time))")
                .accessibilityHint("Clock pulses gently")
        }
        .onAppear {
            scheduleNextMove()
        }
        .onDisappear {
            moveWork?.cancel()
            moveWork = nil
        }
    }

    private var currentPosition: CGPoint {
        if targetPosition == .zero {
            return CGPoint(x: containerSize.width * 0.18, y: containerSize.height * 0.12)
        }
        return targetPosition
    }

    private func scheduleNextMove() {
        moveWork?.cancel()
        let interval: TimeInterval = 20 + Double.random(in: 0...22) // 20–42s between hops
        let work = DispatchWorkItem { moveClock() }
        moveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }

    private func moveClock() {
        guard containerSize.width > 72, containerSize.height > 72 else {
            scheduleNextMove()
            return
        }
        let (estimatedWidth, estimatedHeight): (CGFloat, CGFloat) = {
            #if os(tvOS)
            return (420, 180)
            #else
            switch UIDevice.current.userInterfaceIdiom {
            case .pad: return (300, 140)
            case .tv: return (420, 180)
            default: return (240, 120)
            }
            #endif
        }()
        let marginX = max(36, estimatedWidth / 2 + 20)
        let marginY = max(36, estimatedHeight / 2 + 24)
        let xRange = max(marginX, 0)...max(marginX, containerSize.width - marginX)
        let yRange = max(marginY, 0)...max(marginY, containerSize.height - marginY)
        let x = CGFloat.random(in: xRange)
        let y = CGFloat.random(in: yRange)
        let newPoint = CGPoint(x: x, y: y)

        let fadeOut: TimeInterval = 1.8
        let fadeIn: TimeInterval = 2.0
        let gap: TimeInterval = 0.6

        withAnimation(.easeInOut(duration: fadeOut)) {
            opacity = 0
            scale = 0.92
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut + gap) {
            targetPosition = newPoint
            withAnimation(.easeInOut(duration: fadeIn)) {
                opacity = 1
                scale = 1
            }
        }

        scheduleNextMove()
    }
}

func clockStyle(for mode: DriftMode, idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> ClockStyle {
    let palette = mode.config.palette
    switch idiom {
    case .pad:
        return ClockStyle(
            font: .system(size: 44, weight: .heavy, design: .rounded).monospacedDigit(),
            color: palette.primary,
            tracking: 1.4
        )
    case .tv:
        return ClockStyle(
            font: .system(size: 70, weight: .black, design: .rounded).monospacedDigit(),
            color: palette.primary,
            tracking: 1.8
        )
    default:
        return ClockStyle(
            font: .system(size: 28, weight: .semibold, design: .rounded).monospacedDigit(),
            color: palette.primary,
            tracking: 1.1
        )
    }
}
