import SwiftUI

enum ChromeFocusTarget: Hashable {
    case modePicker, sleepTimer, settings
}

struct ChromeBarView: View {
    let modeName: String
    let modeDescriptor: String
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
        HStack(spacing: isTvOS ? 16 : 12) {
#if os(tvOS)
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    onNextMode()
                }
                DriftHaptics.modeChanged()
            } label: {
                nowPlayingLabelTvOS
            }
            .buttonStyle(.plain)
#else
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    onModePicker()
                }
            } label: {
                HStack(spacing: 10) {
                    nowPlayingLabelIOS
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
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
            .padding(.horizontal, isTvOS ? 10 : 6)
            .padding(.vertical, 4)
            .background(actionsBackground)
        }
        .padding(.vertical, isTvOS ? 2 : 1)
    }

    private var nowPlayingBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(chromeTint.opacity(isTvOS ? 0.07 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(isTvOS ? 0.16 : 0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isTvOS ? 0.22 : 0.16), radius: isTvOS ? 10 : 7, x: 0, y: isTvOS ? 8 : 5)
    }

    private var actionsBackground: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(.ultraThinMaterial.opacity(isTvOS ? 0.82 : 0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(isTvOS ? 0.14 : 0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isTvOS ? 0.20 : 0.14), radius: isTvOS ? 9 : 6, x: 0, y: isTvOS ? 7 : 5)
    }

    private var nowPlayingLabelIOS: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Now Playing")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.64))
            Text(modeName)
                .accessibilityIdentifier("currentModeLabel")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            Text(modeDescriptor)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.68))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(nowPlayingBackground)
    }

    private var nowPlayingLabelTvOS: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Now Playing")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.62))
            Text(modeName)
                .accessibilityIdentifier("currentModeLabel")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.94))
            Text(modeDescriptor)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(nowPlayingBackground)
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
            let visualSize: CGFloat = isTvOS ? 34 : 28
            let hitSize: CGFloat = isTvOS ? 40 : 40
            let fontSize: CGFloat = isTvOS ? 15 : 14

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
#if os(tvOS)
            // tvOS: make the system focus effect follow the circular control, not a big rectangle.
            .contentShape(Circle())
#else
            .contentShape(Rectangle())
#endif
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? systemName)
#if !os(tvOS)
        .buttonStyle(.plain)
#endif
    }
}

#if os(tvOS)
private extension View {
    @ViewBuilder
    func applyFocus(_ binding: FocusState<ChromeFocusTarget?>.Binding?, target: ChromeFocusTarget) -> some View {
        if let binding {
            self.focused(binding, equals: target)
        } else {
            self
        }
    }
}
#endif
