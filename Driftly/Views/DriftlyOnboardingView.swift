import SwiftUI

/// First-launch onboarding for Driftly Ambient.
///
/// Goals:
/// - Works on iOS, iPadOS, and tvOS.
/// - High contrast and readable by default.
/// - Respects Reduce Motion.
struct DriftlyOnboardingView: View {
    struct Page: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let systemImage: String
    }

    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index: Int = 0
#if os(tvOS)
    @FocusState private var primaryButtonFocused: Bool
#endif

    private let pages: [Page] = [
        .init(
            title: "Relax. Focus. Drift.",
            subtitle: "Driftly Ambient fills your screen with living light.",
            systemImage: "sparkles"
        ),
        .init(
            title: "Choose a mode",
            subtitle: "Pick a look in seconds, then let it breathe in the background.",
            systemImage: "wand.and.stars"
        ),
        .init(
            title: "Sleep timer",
            subtitle: "Set a timer and drift off. Driftly fades out on your schedule.",
            systemImage: "moon.zzz"
        ),
        .init(
            title: "Works everywhere",
            subtitle: "Enjoy Driftly on iOS, iPadOS, and tvOS.",
            systemImage: "rectangle.3.group"
        )
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                        OnboardingPage(page: page)
                            .tag(i)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: index)
                .frame(maxWidth: 860)

                Spacer(minLength: 0)

                footerControls
                    .padding(.horizontal, 28)
                    .padding(.bottom, 26)
            }
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
            // Land focus on the primary action for remote-first navigation.
            DispatchQueue.main.async {
                primaryButtonFocused = true
            }
        }
#endif
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("onboarding")
    }

    private var footerControls: some View {
        HStack(spacing: 14) {
            Button {
                if index > 0 { index -= 1 }
            } label: {
                Text("Back").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
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
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .controlSize(.large)
            .accessibilityIdentifier("onboardingPrimary")
#if os(tvOS)
            .focused($primaryButtonFocused)
#endif
        }
        .frame(maxWidth: 860)
        .padding(.top, 8)
    }
}

private struct OnboardingPage: View {
    let page: DriftlyOnboardingView.Page

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: page.systemImage)
                .font(.system(size: 52, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.92))
                .padding(.bottom, 6)

            Text(page.title)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}
