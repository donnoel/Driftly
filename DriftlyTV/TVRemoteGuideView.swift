import SwiftUI

/// Local to this Apple TV installation; replaying the guide never resets app preferences.
enum TVRemoteGuideProgress {
    static let completedVersionKey = "driftly.tvRemoteGuide.completedVersion"
    static let currentVersion = 1

    static func shouldPresent(defaults: UserDefaults = .standard) -> Bool {
        defaults.integer(forKey: completedVersionKey) < currentVersion
    }

    static func complete(defaults: UserDefaults = .standard) {
        defaults.set(currentVersion, forKey: completedVersionKey)
    }
}

struct TVRemoteGuideView: View {
    let onComplete: () -> Void
    @State private var step = 0
    @FocusState private var focusedControl: Control?

    private enum Control: Hashable { case skip, back, next }
    private let accent = Color(red: 0.66, green: 0.91, blue: 0.85)

    private struct Page {
        let category: String
        let title: String
        let instructions: String
        let detail: String
        let symbol: String
        let caption: String
    }

    private static let pages: [Page] = [
        Page(category: "Remote basics", title: "Bring up the controls.",
             instructions: "Press the clickpad center to reveal the controls.\nMove between buttons, then press the center to select.",
             detail: "Back brings the controls back while viewing. On older remotes, use the touch surface and Menu button.",
             symbol: "chevron.backward", caption: "Press the clickpad center"),
        Page(category: "Choose a visual", title: "Find your atmosphere.",
             instructions: "Choose the sparkles button to browse visuals.\nMove to one you like and press the clickpad center.",
             detail: "Select Now Playing to jump to the next visual.",
             symbol: "sparkles", caption: "Move, then press to select"),
        Page(category: "Brightness & full screen", title: "Set the glow.",
             instructions: "Press and hold the clickpad center to hide the controls.\nThen press Up or Down to brighten or dim the visuals.",
             detail: "Press Back to bring the controls back.",
             symbol: "sun.max", caption: "Hold to hide the controls"),
        Page(category: "Sleep timer", title: "Let Driftly wind down.",
             instructions: "Choose the moon button to set a sleep timer.\nPress the clickpad center to wake the visuals when it ends.",
             detail: "15, 30, or 60 minutes — or choose your own duration.",
             symbol: "moon.zzz", caption: "Press to select a duration")
    ]

    var body: some View {
        let page = Self.pages[step]
        ZStack {
            LinearGradient(colors: [Color(red: 0.025, green: 0.045, blue: 0.085),
                                    Color(red: 0.04, green: 0.10, blue: 0.15)],
                           startPoint: .bottomLeading, endPoint: .topTrailing)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                HStack {
                    Text("DRIFTLY NIGHT")
                        .font(.caption.weight(.semibold))
                        .tracking(5)
                        .foregroundStyle(accent)
                    Spacer()
                    Button("Skip", action: onComplete)
                        .buttonStyle(.borderless)
                        .focused($focusedControl, equals: .skip)
                        .accessibilityIdentifier("remoteGuideSkip")
                }

                HStack(spacing: 90) {
                    VStack(alignment: .leading, spacing: 28) {
                        Text(page.category.uppercased())
                            .font(.caption.weight(.medium))
                            .tracking(3)
                            .foregroundStyle(accent)
                        Text(page.title)
                            .font(.largeTitle.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("remoteGuideTitle")
                        Text(page.instructions)
                            .font(.title3)
                            .foregroundStyle(Color.white.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                        Label(page.detail, systemImage: page.symbol)
                            .font(.body)
                            .foregroundStyle(accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 24) {
                        TVRemoteGuideDiagram(step: step, accent: accent)
                            .frame(width: 220, height: 600)
                            .accessibilityHidden(true)
                        Text(page.caption)
                            .font(.footnote)
                            .foregroundStyle(accent)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 400)
                }
                .frame(maxHeight: .infinity)

                HStack {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .focused($focusedControl, equals: .back)
                            .accessibilityIdentifier("remoteGuideBack")
                    }
                    Spacer()
                    HStack(spacing: 14) {
                        Text("\(step + 1) of \(Self.pages.count)")
                            .font(.footnote.monospacedDigit())
                        ForEach(Self.pages.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == step ? accent : Color.white.opacity(0.25))
                                .frame(width: index == step ? 28 : 9, height: 9)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Step \(step + 1) of \(Self.pages.count)")
                    Spacer()
                    Button(step == Self.pages.count - 1 ? "Start Driftly" : "Continue") {
                        if step == Self.pages.count - 1 { onComplete() }
                        else { step += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .focused($focusedControl, equals: .next)
                    .accessibilityIdentifier("remoteGuideNext")
                }
            }
            .padding(.horizontal, 100)
            .padding(.vertical, 60)
        }
        .preferredColorScheme(.dark)
        .defaultFocus($focusedControl, .next)
        .onChange(of: step) { _, _ in focusedControl = .next }
        .onExitCommand {
            if step > 0 { step -= 1 }
            else { onComplete() }
        }
    }
}

private struct TVRemoteGuideDiagram: View {
    let step: Int
    let accent: Color

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                remoteButton("power", size: 28)
            }
            ZStack {
                Circle().fill(step == 1 ? accent.opacity(0.6) : Color(white: 0.18))
                Circle()
                    .fill(step == 2 ? Color(white: 0.10) : accent)
                    .overlay(Circle().strokeBorder(accent, lineWidth: 2))
                    .padding(39)
                VStack {
                    direction("chevron.up")
                    Spacer()
                    direction("chevron.down")
                }
                .padding(.vertical, 10)
                HStack {
                    Image(systemName: "chevron.left")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 15)
                .foregroundStyle(Color.white.opacity(0.6))
            }
            .frame(height: 184)
            HStack(spacing: 20) {
                VStack(spacing: 20) {
                    remoteButton("chevron.backward")
                    remoteButton("playpause.fill")
                    remoteButton("speaker.slash.fill")
                }
                VStack(spacing: 20) {
                    remoteButton("tv")
                    VStack {
                        Text("+")
                        Spacer()
                        Text("−")
                    }
                    .font(.title3)
                    .frame(width: 68, height: 156)
                    .padding(.vertical, 16)
                    .background(Color(white: 0.15), in: Capsule())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color(white: 0.60), Color(white: 0.83), Color(white: 0.64)],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 42, style: .continuous)
        )
        .shadow(color: .black.opacity(0.35), radius: 25, y: 15)
    }

    private func direction(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(step == 2 ? Color.black : Color.white.opacity(0.6))
            .frame(width: 28, height: 24)
            .background(step == 2 ? accent : .clear, in: Capsule())
    }

    private func remoteButton(_ name: String, size: CGFloat = 68) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.35, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.85))
            .frame(width: size, height: size)
            .background(Color(white: 0.15), in: Circle())
    }
}
