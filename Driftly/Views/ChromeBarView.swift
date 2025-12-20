import SwiftUI

enum ChromeFocusTarget: Hashable {
    case modePicker, sleepTimer, settings
}

struct ChromeBarView: View {
    let modeName: String
    let chromeTint: Color
    let isTvOS: Bool
    let sleepTimerActive: Bool
    let onModePicker: () -> Void
    let onSleepTimer: () -> Void
    let onSettings: () -> Void
    let onNextMode: () -> Void
#if os(tvOS)
    var focusedButton: FocusState<ChromeFocusTarget?>.Binding?
#endif

    var body: some View {
        HStack(spacing: 12) {
#if os(tvOS)
            VStack(alignment: .leading, spacing: 4) {
                Text(modeName)
                    .accessibilityIdentifier("currentModeLabel")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.35)) {
                    onNextMode()
                }
                DriftHaptics.modeChanged()
            }
#else
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    onModePicker()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(modeName)
                        .accessibilityIdentifier("currentModeLabel")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("modePickerButton")
            .accessibilityLabel("Choose mode")
            .accessibilityHint("Opens the mode picker")
#endif

            Spacer()

            HStack(spacing: isTvOS ? 40 : 12) {
#if os(tvOS)
                CircleButton(systemName: "sparkles", action: {
                    onModePicker()
                }, accessibilityIdentifier: "modePickerButton", isTvOS: isTvOS, tintColor: chromeTint)
                .applyFocus(focusedButton, target: .modePicker)
#endif
                CircleButton(systemName: "moon.zzz", action: {
                    onSleepTimer()
                }, accessibilityIdentifier: "sleepTimerButton", isActive: sleepTimerActive, isTvOS: isTvOS, tintColor: chromeTint)
#if os(tvOS)
                .applyFocus(focusedButton, target: .sleepTimer)
#endif

                CircleButton(systemName: "gearshape", action: {
                    onSettings()
                }, accessibilityIdentifier: "settingsButton", isTvOS: isTvOS, tintColor: chromeTint)
#if os(tvOS)
                .applyFocus(focusedButton, target: .settings)
#endif
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(chromeBackground)
        .opacity(0.62)
    }

    @ViewBuilder
    private var chromeBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let tint = chromeTint.opacity(0.26)
        shape
            .fill(.ultraThinMaterial.opacity(0.45))
            .overlay(
                shape
                    .stroke(tint, lineWidth: 1)
            )
            .shadow(color: tint.opacity(0.15), radius: 5, x: 0, y: 3)
    }
}

private struct CircleButton: View {
    let systemName: String
    let action: () -> Void
    var accessibilityIdentifier: String? = nil
    var isActive: Bool = false
    var isTvOS: Bool = false
    var tintColor: Color? = nil

    var body: some View {
        Button(action: action) {
            let baseTint = tintColor ?? Color.white
            let tint = isActive ? baseTint.opacity(0.92) : baseTint.opacity(0.86)
            let visualSize: CGFloat = isTvOS ? 38 : 32
            let hitSize: CGFloat = isTvOS ? 40 : 44
            let fontSize: CGFloat = isTvOS ? 16 : 15

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: visualSize, height: visualSize)
                    .background(.ultraThinMaterial.opacity(0.5), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(tint.opacity(isActive ? 0.9 : 0.55), lineWidth: 1)
                    )

                Image(systemName: systemName)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: hitSize, height: hitSize)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? systemName)
        .buttonStyle(.plain)
    }
}

#if os(tvOS)
private extension View {
    func applyFocus(_ binding: FocusState<ChromeFocusTarget?>.Binding?, target: ChromeFocusTarget) -> some View {
        guard let binding else { return AnyView(self) }
        return AnyView(self.focused(binding, equals: target))
    }
}
#endif
