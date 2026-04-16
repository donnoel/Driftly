import SwiftUI
#if os(iOS)
import UIKit
#endif

fileprivate struct OnboardingPalette {
    let backgroundTop: Color
    let backgroundBottom: Color
    let glowPrimary: Color
    let glowSecondary: Color
    let glowAccent: Color
    let panelHighlight: Color
}

fileprivate struct OnboardingPageModel: Identifiable {
    enum Kind: Int, Identifiable {
        case welcome
        case atmosphere
        case drift
        case ready

        var id: Int { rawValue }
    }

    let id: Kind
    let eyebrow: String
    let title: String
    let subtitle: String
    let tags: [String]
    let palette: OnboardingPalette
}

fileprivate enum OnboardingLayoutStyle {
    case phone
    case pad
    case tv
}

/// First-launch onboarding for Driftly.
///
/// Goals:
/// - Works on iOS, iPadOS, and tvOS.
/// - Feels premium and product-specific.
/// - Respects Reduce Motion.
struct DriftlyOnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index: Int = 0
#if os(tvOS)
    @FocusState private var primaryButtonFocused: Bool
#endif

    private let pages: [OnboardingPageModel] = [
        .init(
            id: .welcome,
            eyebrow: "Welcome to Driftly",
            title: "Living light for quiet rooms.",
            subtitle: "A calm ambient screen for reading, resting, and settling the mood around you.",
            tags: ["Calm", "Focus", "Drift"],
            palette: OnboardingPalette(
                backgroundTop: Color(red: 0.03, green: 0.06, blue: 0.13),
                backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.03),
                glowPrimary: Color(red: 0.37, green: 0.83, blue: 1.00),
                glowSecondary: Color(red: 0.43, green: 0.35, blue: 0.93),
                glowAccent: Color(red: 0.92, green: 0.50, blue: 0.76),
                panelHighlight: Color(red: 0.28, green: 0.70, blue: 0.92)
            )
        ),
        .init(
            id: .atmosphere,
            eyebrow: "Choose your atmosphere",
            title: "Pick a mode in a glance.",
            subtitle: "Shift the room from luminous and airy to deep, cinematic, or slow and lunar.",
            tags: ["Aurora Veil", "Cosmic Tide", "Lunar Drift"],
            palette: OnboardingPalette(
                backgroundTop: Color(red: 0.05, green: 0.07, blue: 0.14),
                backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.03),
                glowPrimary: Color(red: 0.34, green: 0.93, blue: 0.83),
                glowSecondary: Color(red: 0.27, green: 0.50, blue: 1.00),
                glowAccent: Color(red: 1.00, green: 0.63, blue: 0.47),
                panelHighlight: Color(red: 0.29, green: 0.76, blue: 0.85)
            )
        ),
        .init(
            id: .drift,
            eyebrow: "Let Driftly drift with you",
            title: "Stay in motion, then fade out softly.",
            subtitle: "Set a timer for the evening, or let Auto Drift move between moods while you unwind.",
            tags: ["Sleep Timer", "Auto Drift", "Quiet Exit"],
            palette: OnboardingPalette(
                backgroundTop: Color(red: 0.06, green: 0.05, blue: 0.12),
                backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.03),
                glowPrimary: Color(red: 0.97, green: 0.73, blue: 0.45),
                glowSecondary: Color(red: 0.47, green: 0.42, blue: 0.96),
                glowAccent: Color(red: 0.49, green: 0.86, blue: 0.97),
                panelHighlight: Color(red: 0.84, green: 0.66, blue: 0.44)
            )
        ),
        .init(
            id: .ready,
            eyebrow: "Ready to begin",
            title: "Enter the experience.",
            subtitle: "Start with a mode, let the chrome fall away, and leave the room to the light.",
            tags: ["Choose Mode", "Settle In", "Get Started"],
            palette: OnboardingPalette(
                backgroundTop: Color(red: 0.03, green: 0.05, blue: 0.11),
                backgroundBottom: Color(red: 0.01, green: 0.01, blue: 0.03),
                glowPrimary: Color(red: 0.85, green: 0.95, blue: 1.00),
                glowSecondary: Color(red: 0.47, green: 0.74, blue: 1.00),
                glowAccent: Color(red: 0.61, green: 0.52, blue: 0.98),
                panelHighlight: Color(red: 0.74, green: 0.90, blue: 0.97)
            )
        )
    ]

    var body: some View {
        GeometryReader { proxy in
            let layout = layoutStyle
            let currentPage = pages[index]

            ZStack {
                OnboardingBackdrop(page: currentPage, layout: layout)

                VStack(spacing: verticalSpacing(for: layout)) {
                    header(for: currentPage, layout: layout)

                    TabView(selection: $index) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { pageIndex, page in
                            OnboardingPage(
                                page: page,
                                layout: layout,
                                reduceMotion: reduceMotion
                            )
                            .tag(pageIndex)
                            .padding(.horizontal, horizontalPagePadding(for: layout))
                            .padding(.vertical, layout == .phone ? 8 : 12)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: index)
                    .frame(maxWidth: maxContentWidth(for: layout))

                    footerControls(layout: layout)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, outerHorizontalPadding(for: layout))
                .padding(.top, outerTopPadding(for: layout))
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, footerBottomPadding(for: layout)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
#if os(tvOS)
        .onMoveCommand { direction in
            switch direction {
            case .left:
                if index > 0 { index -= 1 }
            case .right:
                if index < pages.count - 1 { index += 1 }
            default:
                break
            }
        }
        .onExitCommand {
            // Don’t trap the user in onboarding on Apple TV.
            onFinish()
        }
        .onAppear {
            DispatchQueue.main.async {
                primaryButtonFocused = true
            }
        }
#endif
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("onboarding")
    }

    private var layoutStyle: OnboardingLayoutStyle {
#if os(tvOS)
        return .tv
#else
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
#endif
    }

    private func header(for page: OnboardingPageModel, layout: OnboardingLayoutStyle) -> some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 12) {
                DriftlyMark(
                    primary: page.palette.glowPrimary,
                    secondary: page.palette.glowSecondary,
                    accent: page.palette.glowAccent
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Driftly")
                        .font(layout == .tv ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.96))

                    Text("Ambient light, tuned for the room.")
                        .font(layout == .phone ? .caption2 : .caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                pageIndicators

                Text("\(index + 1) / \(pages.count)")
                    .font(layout == .tv ? .footnote.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.74))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, headerHorizontalPadding(for: layout))
        .padding(.vertical, headerVerticalPadding(for: layout))
        .background(headerBackground(for: page, layout: layout))
        .frame(maxWidth: maxContentWidth(for: layout))
    }

    private var pageIndicators: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { pageIndex in
                Capsule(style: .continuous)
                    .fill(pageIndex == index ? Color.white.opacity(0.92) : Color.white.opacity(0.22))
                    .frame(width: pageIndex == index ? 24 : 7, height: 7)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: index)
    }

    private func footerControls(layout: OnboardingLayoutStyle) -> some View {
        VStack(spacing: layout == .phone ? 14 : 18) {
            if layout != .tv {
                Text("Swipe or use Continue to move through the introduction.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.56))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Swipe the Siri Remote to browse, then begin with the focused action.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.58))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 14) {
                Button {
                    if index > 0 { index -= 1 }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(layout == .phone ? .large : .regular)
                .accessibilityIdentifier("onboardingBack")
                .disabled(index == 0)

                Button {
                    if index < pages.count - 1 {
                        index += 1
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(index < pages.count - 1 ? "Continue" : "Get Started")
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .controlSize(layout == .phone ? .large : .regular)
                .accessibilityIdentifier("onboardingPrimary")
#if os(tvOS)
                .focused($primaryButtonFocused)
#endif
            }
        }
        .padding(.horizontal, layout == .phone ? 18 : 22)
        .padding(.vertical, layout == .phone ? 18 : 20)
        .background(
            RoundedRectangle(cornerRadius: layout == .phone ? 24 : 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(layout == .tv ? 0.09 : 0.08),
                            Color.white.opacity(0.02),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: layout == .phone ? 24 : 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .frame(maxWidth: layout == .tv ? 1040 : maxContentWidth(for: layout))
    }

    private func headerBackground(for page: OnboardingPageModel, layout: OnboardingLayoutStyle) -> some View {
        RoundedRectangle(cornerRadius: layout == .phone ? 22 : 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(layout == .tv ? 0.10 : 0.08),
                        page.palette.panelHighlight.opacity(0.10),
                        Color.black.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: layout == .phone ? 22 : 26, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    private func maxContentWidth(for layout: OnboardingLayoutStyle) -> CGFloat {
        switch layout {
        case .phone:
            return 560
        case .pad:
            return 1180
        case .tv:
            return 1260
        }
    }

    private func verticalSpacing(for layout: OnboardingLayoutStyle) -> CGFloat {
        switch layout {
        case .phone:
            return 18
        case .pad:
            return 22
        case .tv:
            return 28
        }
    }

    private func outerHorizontalPadding(for layout: OnboardingLayoutStyle) -> CGFloat {
        switch layout {
        case .phone:
            return 16
        case .pad:
            return 28
        case .tv:
            return 42
        }
    }

    private func outerTopPadding(for layout: OnboardingLayoutStyle) -> CGFloat {
        switch layout {
        case .phone:
            return 18
        case .pad:
            return 26
        case .tv:
            return 34
        }
    }

    private func footerBottomPadding(for layout: OnboardingLayoutStyle) -> CGFloat {
        switch layout {
        case .phone:
            return 18
        case .pad:
            return 24
        case .tv:
            return 32
        }
    }

    private func horizontalPagePadding(for layout: OnboardingLayoutStyle) -> CGFloat {
        switch layout {
        case .phone:
            return 0
        case .pad:
            return 6
        case .tv:
            return 10
        }
    }

    private func headerHorizontalPadding(for layout: OnboardingLayoutStyle) -> CGFloat {
        switch layout {
        case .phone:
            return 16
        case .pad:
            return 20
        case .tv:
            return 24
        }
    }

    private func headerVerticalPadding(for layout: OnboardingLayoutStyle) -> CGFloat {
        switch layout {
        case .phone:
            return 14
        case .pad:
            return 16
        case .tv:
            return 18
        }
    }
}

private struct OnboardingPage: View {
    let page: OnboardingPageModel
    let layout: OnboardingLayoutStyle
    let reduceMotion: Bool

    var body: some View {
        Group {
            switch layout {
            case .phone:
                phoneLayout
            case .pad, .tv:
                wideLayout
            }
        }
        .padding(surfacePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageSurface)
        .clipShape(RoundedRectangle(cornerRadius: surfaceCornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var phoneLayout: some View {
        VStack(alignment: .leading, spacing: 24) {
            artwork
                .frame(height: 302)

            copyBlock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var wideLayout: some View {
        HStack(spacing: layout == .tv ? 52 : 38) {
            copyBlock
                .frame(maxWidth: layout == .tv ? 400 : 360, alignment: .leading)

            artwork
                .frame(maxWidth: .infinity, minHeight: layout == .tv ? 460 : 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: layout == .phone ? 14 : 18) {
            Text(page.eyebrow)
                .font(layout == .tv ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(page.palette.panelHighlight.opacity(0.94))

            Text(page.title)
                .font(titleFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(page.subtitle)
                .font(subtitleFont)
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(page.tags, id: \.self) { tag in
                        Text(tag)
                            .font(layout == .tv ? .footnote.weight(.semibold) : .caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.vertical, 1)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var artwork: some View {
        switch page.id {
        case .welcome:
            WelcomeArtwork(page: page, layout: layout, reduceMotion: reduceMotion)
        case .atmosphere:
            AtmosphereArtwork(page: page, layout: layout)
        case .drift:
            DriftArtwork(page: page, layout: layout)
        case .ready:
            ReadyArtwork(page: page, layout: layout)
        }
    }

    private var pageSurface: some View {
        RoundedRectangle(cornerRadius: surfaceCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(layout == .tv ? 0.09 : 0.08),
                        page.palette.panelHighlight.opacity(0.10),
                        Color.black.opacity(0.26)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: surfaceCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(page.palette.glowPrimary.opacity(0.22))
                    .frame(width: layout == .tv ? 340 : 220, height: layout == .tv ? 340 : 220)
                    .blur(radius: layout == .tv ? 44 : 32)
                    .offset(x: -surfacePadding * 0.4, y: -surfacePadding * 0.3)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(page.palette.glowSecondary.opacity(0.18))
                    .frame(width: layout == .tv ? 300 : 200, height: layout == .tv ? 300 : 200)
                    .blur(radius: layout == .tv ? 48 : 34)
                    .offset(x: surfacePadding * 0.35, y: surfacePadding * 0.45)
            }
    }

    private var titleFont: Font {
        switch layout {
        case .phone:
            return .system(size: 34, weight: .semibold, design: .rounded)
        case .pad:
            return .system(size: 48, weight: .semibold, design: .rounded)
        case .tv:
            return .system(size: 60, weight: .semibold, design: .rounded)
        }
    }

    private var subtitleFont: Font {
        switch layout {
        case .phone:
            return .system(size: 17, weight: .regular, design: .rounded)
        case .pad:
            return .system(size: 22, weight: .regular, design: .rounded)
        case .tv:
            return .system(size: 26, weight: .regular, design: .rounded)
        }
    }

    private var surfacePadding: CGFloat {
        switch layout {
        case .phone:
            return 22
        case .pad:
            return 30
        case .tv:
            return 36
        }
    }

    private var surfaceCornerRadius: CGFloat {
        switch layout {
        case .phone:
            return 34
        case .pad:
            return 40
        case .tv:
            return 44
        }
    }
}

private struct OnboardingBackdrop: View {
    let page: OnboardingPageModel
    let layout: OnboardingLayoutStyle

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    page.palette.backgroundTop,
                    Color.black,
                    page.palette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(page.palette.glowPrimary.opacity(0.34))
                .frame(width: layout == .tv ? 740 : 520, height: layout == .tv ? 740 : 520)
                .blur(radius: layout == .tv ? 90 : 70)
                .offset(x: layout == .tv ? -340 : -180, y: layout == .tv ? -220 : -160)

            Circle()
                .fill(page.palette.glowSecondary.opacity(0.26))
                .frame(width: layout == .tv ? 680 : 460, height: layout == .tv ? 680 : 460)
                .blur(radius: layout == .tv ? 110 : 82)
                .offset(x: layout == .tv ? 360 : 160, y: layout == .tv ? -120 : -40)

            Circle()
                .fill(page.palette.glowAccent.opacity(0.18))
                .frame(width: layout == .tv ? 680 : 420, height: layout == .tv ? 680 : 420)
                .blur(radius: layout == .tv ? 118 : 90)
                .offset(x: layout == .tv ? 280 : 140, y: layout == .tv ? 280 : 220)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.02),
                            Color.clear,
                            Color.black.opacity(0.34)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }
}

private struct DriftlyMark: View {
    let primary: Color
    let secondary: Color
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(primary.opacity(0.94))
                .frame(width: 14, height: 14)
                .offset(x: -7, y: -2)

            Circle()
                .fill(secondary.opacity(0.88))
                .frame(width: 12, height: 12)
                .offset(x: 8, y: 2)

            Circle()
                .fill(accent.opacity(0.84))
                .frame(width: 8, height: 8)
                .offset(x: 1, y: -8)
        }
        .frame(width: 28, height: 28)
        .background(
            Circle()
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct WelcomeArtwork: View {
    let page: OnboardingPageModel
    let layout: OnboardingLayoutStyle
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: layout == .phone ? 28 : 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            page.palette.panelHighlight.opacity(0.10),
                            Color.black.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: layout == .phone ? 28 : 34, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            Circle()
                .fill(page.palette.glowPrimary.opacity(0.72))
                .frame(width: layout == .tv ? 260 : 180, height: layout == .tv ? 260 : 180)
                .blur(radius: layout == .tv ? 28 : 18)
                .offset(x: layout == .tv ? -120 : -52, y: layout == .tv ? -42 : -18)

            Circle()
                .fill(page.palette.glowSecondary.opacity(0.56))
                .frame(width: layout == .tv ? 220 : 150, height: layout == .tv ? 220 : 150)
                .blur(radius: layout == .tv ? 32 : 22)
                .offset(x: layout == .tv ? 96 : 36, y: layout == .tv ? 24 : 18)

            Circle()
                .fill(page.palette.glowAccent.opacity(0.42))
                .frame(width: layout == .tv ? 170 : 112, height: layout == .tv ? 170 : 112)
                .blur(radius: layout == .tv ? 28 : 18)
                .offset(x: layout == .tv ? 132 : 62, y: layout == .tv ? -86 : -56)

            VStack(alignment: .leading, spacing: layout == .tv ? 18 : 14) {
                Text("A room that feels softly alive.")
                    .font(layout == .tv ? .title3.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))

                Text("Driftly fills the screen with movement that stays calm, slow, and easy to live with.")
                    .font(layout == .tv ? .title3 : .subheadline)
                    .foregroundStyle(.white.opacity(0.70))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Text("Premium ambient scenes")
                    Text("Built for the whole room")
                }
                .font(layout == .tv ? .footnote.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
            }
            .padding(layout == .tv ? 32 : 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .shadow(color: Color.black.opacity(reduceMotion ? 0.16 : 0.22), radius: layout == .tv ? 24 : 16, x: 0, y: 14)
    }
}

private struct AtmosphereArtwork: View {
    let page: OnboardingPageModel
    let layout: OnboardingLayoutStyle

    var body: some View {
        HStack(spacing: layout == .tv ? 20 : 14) {
            modeCard(
                name: "Aurora Veil",
                detail: "Luminous and airy",
                primary: Color(red: 0.48, green: 0.96, blue: 0.88),
                secondary: Color(red: 0.31, green: 0.56, blue: 1.00),
                highlight: Color(red: 0.95, green: 0.98, blue: 1.00)
            )
            .rotationEffect(.degrees(layout == .phone ? -4 : -6))
            .offset(y: layout == .phone ? 10 : 18)

            modeCard(
                name: "Cosmic Tide",
                detail: "Deep and cinematic",
                primary: Color(red: 0.34, green: 0.47, blue: 1.00),
                secondary: Color(red: 0.90, green: 0.38, blue: 0.84),
                highlight: Color(red: 0.88, green: 0.92, blue: 1.00)
            )
            .offset(y: layout == .phone ? -10 : -18)

            modeCard(
                name: "Lunar Drift",
                detail: "Slow and lunar",
                primary: Color(red: 0.99, green: 0.76, blue: 0.48),
                secondary: Color(red: 0.60, green: 0.50, blue: 0.97),
                highlight: Color(red: 1.00, green: 0.96, blue: 0.90)
            )
            .rotationEffect(.degrees(layout == .phone ? 5 : 7))
            .offset(y: layout == .phone ? 14 : 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, layout == .phone ? 8 : 12)
    }

    private func modeCard(
        name: String,
        detail: String,
        primary: Color,
        secondary: Color,
        highlight: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: layout == .tv ? 14 : 10) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            highlight.opacity(0.80),
                            primary.opacity(0.84),
                            secondary.opacity(0.86),
                            Color.black.opacity(0.70)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .fill(highlight.opacity(0.35))
                        .frame(width: layout == .tv ? 100 : 72, height: layout == .tv ? 100 : 72)
                        .blur(radius: layout == .tv ? 20 : 14)
                        .offset(x: -16, y: -12)
                )
                .frame(height: layout == .tv ? 220 : 150)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(layout == .tv ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(layout == .tv ? .footnote : .caption)
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .padding(layout == .tv ? 16 : 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            page.palette.panelHighlight.opacity(0.10),
                            Color.black.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct DriftArtwork: View {
    let page: OnboardingPageModel
    let layout: OnboardingLayoutStyle

    var body: some View {
        VStack(spacing: layout == .tv ? 18 : 14) {
            HStack(spacing: layout == .tv ? 18 : 14) {
                featurePanel(
                    title: "Sleep Timer",
                    detail: "Fade out on your schedule.",
                    icon: "moon.zzz.fill",
                    tint: page.palette.glowPrimary
                )

                featurePanel(
                    title: "Auto Drift",
                    detail: "Move between moods gently.",
                    icon: "sparkles",
                    tint: page.palette.glowSecondary
                )
            }

            timelinePanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featurePanel(title: String, detail: String, icon: String, tint: Color) -> some View {
        HStack(spacing: layout == .tv ? 16 : 12) {
            Image(systemName: icon)
                .font(layout == .tv ? .title2.weight(.semibold) : .headline.weight(.semibold))
                .foregroundStyle(tint.opacity(0.95))
                .frame(width: layout == .tv ? 50 : 42, height: layout == .tv ? 50 : 42)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(layout == .tv ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(layout == .tv ? .footnote : .caption)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer(minLength: 0)
        }
        .padding(layout == .tv ? 20 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var timelinePanel: some View {
        VStack(alignment: .leading, spacing: layout == .tv ? 18 : 14) {
            Text("Tonight")
                .font(layout == .tv ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))

            HStack(spacing: layout == .tv ? 20 : 14) {
                timeBadge(time: "10:15")
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                page.palette.glowPrimary.opacity(0.90),
                                page.palette.glowSecondary.opacity(0.85),
                                page.palette.glowAccent.opacity(0.70)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: layout == .tv ? 14 : 10)
                timeBadge(time: "11:00")
            }

            HStack {
                Text("Mode shifts softly while you settle in.")
                Spacer(minLength: 12)
                Text("Screen fades to rest at the end.")
            }
            .font(layout == .tv ? .footnote : .caption)
            .foregroundStyle(.white.opacity(0.66))
        }
        .padding(layout == .tv ? 22 : 18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            page.palette.panelHighlight.opacity(0.14),
                            Color.white.opacity(0.06),
                            Color.black.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.11), lineWidth: 1)
                )
        )
    }

    private func timeBadge(time: String) -> some View {
        Text(time)
            .font(layout == .tv ? .footnote.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.86))
            .monospacedDigit()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
    }
}

private struct ReadyArtwork: View {
    let page: OnboardingPageModel
    let layout: OnboardingLayoutStyle

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: layout == .tv ? 36 : 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            page.palette.panelHighlight.opacity(0.12),
                            Color.black.opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: layout == .tv ? 36 : 30, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            Circle()
                .fill(page.palette.glowPrimary.opacity(0.62))
                .frame(width: layout == .tv ? 280 : 180, height: layout == .tv ? 280 : 180)
                .blur(radius: layout == .tv ? 38 : 28)

            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: layout == .tv ? 360 : 240, height: layout == .tv ? 360 : 240)

            VStack(spacing: layout == .tv ? 18 : 14) {
                DriftlyMark(
                    primary: page.palette.glowPrimary,
                    secondary: page.palette.glowSecondary,
                    accent: page.palette.glowAccent
                )
                .scaleEffect(layout == .tv ? 1.8 : 1.5)

                Text("Choose a mode and let the room exhale.")
                    .font(layout == .tv ? .title3.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))

                Text("The introduction ends here. The atmosphere begins next.")
                    .font(layout == .tv ? .body : .subheadline)
                    .foregroundStyle(.white.opacity(0.70))

                HStack(spacing: 10) {
                    Text("Mode Picker")
                    Text("Then Begin")
                }
                .font(layout == .tv ? .footnote.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
            }
            .multilineTextAlignment(.center)
            .padding(layout == .tv ? 34 : 24)
        }
    }
}
