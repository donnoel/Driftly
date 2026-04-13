import SwiftUI
#if os(iOS)
import UIKit
#endif

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
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    #if os(tvOS)
    var focusedButton: FocusState<ChromeFocusTarget?>.Binding?
    #endif

    var body: some View {
#if os(tvOS)
        tvOSLayout
#else
        Group {
            if isPadLayout {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
#endif
    }

    private var nowPlayingBackgroundTvOS: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(chromeTint.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 8)
    }

    private var actionsBackgroundTvOS: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 9, x: 0, y: 7)
    }

    private var iPhoneShellBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(chromeTint.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 6)
    }

    private var iPadNowPlayingBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.74))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(chromeTint.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 9, x: 0, y: 6)
    }

    private var actionsBackgroundIOS: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.68))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 4)
    }

    private var nowPlayingLabelIOS: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Now Playing")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.62))
            Text(modeName)
                .accessibilityIdentifier("currentModeLabel")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            Text(modeDescriptor)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.70))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var nowPlayingLabelIOSPad: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Now Playing")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.64))
            Text(modeName)
                .accessibilityIdentifier("currentModeLabel")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
            Text(modeDescriptor)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minWidth: 320, alignment: .leading)
        .background(iPadNowPlayingBackground)
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
        .background(nowPlayingBackgroundTvOS)
    }

    private var modePickerButtonIOS: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.35)) {
                onModePicker()
            }
        } label: {
            HStack(spacing: isPadLayout ? 12 : 10) {
                if isPadLayout {
                    nowPlayingLabelIOSPad
                } else {
                    nowPlayingLabelIOS
                }
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .padding(.horizontal, isPadLayout ? 4 : 2)
            .padding(.vertical, isPadLayout ? 0 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("modePickerButton")
        .accessibilityLabel("Choose mode")
        .accessibilityHint("Opens the mode picker")
    }

    private var actionButtonsIOS: some View {
        HStack(spacing: isPadLayout ? 10 : 8) {
            CircleButton(systemName: "moon.zzz", action: {
                onSleepTimer()
            }, accessibilityIdentifier: "sleepTimerButton", isActive: sleepTimerActive, isTvOS: false, isPadOS: isPadLayout, tintColor: chromeTint)

            CircleButton(systemName: "gearshape", action: {
                onSettings()
            }, accessibilityIdentifier: "settingsButton", isTvOS: false, isPadOS: isPadLayout, tintColor: chromeTint)
        }
        .padding(.horizontal, isPadLayout ? 10 : 8)
        .padding(.vertical, isPadLayout ? 8 : 6)
        .background(actionsBackgroundIOS)
    }

    private var iPhoneLayout: some View {
        HStack(spacing: 12) {
            modePickerButtonIOS

            Spacer(minLength: 8)

            actionButtonsIOS
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(iPhoneShellBackground)
        .padding(.vertical, 1)
    }

    private var iPadLayout: some View {
        HStack(spacing: 16) {
            modePickerButtonIOS
            Spacer(minLength: 16)
            actionButtonsIOS
        }
        .padding(.vertical, 2)
    }

    #if os(tvOS)
    private var tvOSLayout: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    onNextMode()
                }
                DriftHaptics.modeChanged()
            } label: {
                nowPlayingLabelTvOS
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 40) {
                CircleButton(systemName: "sparkles", action: {
                    onModePicker()
                }, accessibilityIdentifier: "modePickerButton", isTvOS: true, tintColor: chromeTint)
                .applyFocus(focusedButton, target: .modePicker)

                CircleButton(systemName: "moon.zzz", action: {
                    onSleepTimer()
                }, accessibilityIdentifier: "sleepTimerButton", isActive: sleepTimerActive, isTvOS: true, tintColor: chromeTint)
                .applyFocus(focusedButton, target: .sleepTimer)

                CircleButton(systemName: "gearshape", action: {
                    onSettings()
                }, accessibilityIdentifier: "settingsButton", isTvOS: true, tintColor: chromeTint)
                .applyFocus(focusedButton, target: .settings)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(actionsBackgroundTvOS)
        }
        .padding(.vertical, 2)
    }
    #endif

    private var isPadLayout: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
        #else
        false
        #endif
    }
}

private struct CircleButton: View {
    let systemName: String
    let action: () -> Void
    var accessibilityIdentifier: String? = nil
    var isActive: Bool = false
    var isTvOS: Bool = false
    var isPadOS: Bool = false
    var tintColor: Color? = nil

    var body: some View {
        Button(action: action) {
            let baseTint = tintColor ?? Color.white
            let tint = isActive ? baseTint.opacity(0.92) : baseTint.opacity(0.86)
            let visualSize: CGFloat = isTvOS ? 34 : (isPadOS ? 31 : 28)
            let hitSize: CGFloat = isTvOS ? 40 : (isPadOS ? 42 : 40)
            let fontSize: CGFloat = isTvOS ? 15 : (isPadOS ? 15 : 14)

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
