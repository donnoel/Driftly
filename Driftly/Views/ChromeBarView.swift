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

    private var chromeOpacity: Double { isTvOS ? 0.82 : 0.78 }
    private var chromeCornerRadius: CGFloat { isTvOS ? 22 : 18 }
    private var chromePaddingV: CGFloat { isTvOS ? 12 : 10 }
    private var chromePaddingH: CGFloat { isTvOS ? 16 : 12 }

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
        .padding(.vertical, chromePaddingV)
        .padding(.horizontal, chromePaddingH)
        .background(chromeBackground)
        .opacity(chromeOpacity)
    }

    @ViewBuilder
    private var chromeBackground: some View {
        let shape = RoundedRectangle(cornerRadius: chromeCornerRadius, style: .continuous)
        let tint = chromeTint

        shape
            .fill(.ultraThinMaterial)
            // Soft, mode-tinted base wash
            .overlay(shape.fill(tint.opacity(isTvOS ? 0.10 : 0.08)))
            // Specular highlight (top edge) + gentle falloff
            .overlay(
                shape
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(isTvOS ? 0.22 : 0.18), location: 0.0),
                                .init(color: Color.white.opacity(0.06), location: 0.22),
                                .init(color: Color.clear, location: 0.75)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
            // Crisp glass edge + subtle inner depth
            .overlay(shape.stroke(Color.white.opacity(isTvOS ? 0.18 : 0.14), lineWidth: 1).allowsHitTesting(false))
            .overlay(shape.stroke(tint.opacity(isTvOS ? 0.32 : 0.26), lineWidth: 1).allowsHitTesting(false))
            .overlay(
                shape
                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
                    .blur(radius: 0.8)
                    .offset(y: 1)
                    .mask(shape)
                    .allowsHitTesting(false)
            )
            // Lift off the background (tuned per platform)
            .shadow(color: Color.black.opacity(isTvOS ? 0.32 : 0.22), radius: isTvOS ? 14 : 10, x: 0, y: isTvOS ? 10 : 8)
            .shadow(color: tint.opacity(isTvOS ? 0.16 : 0.12), radius: isTvOS ? 16 : 12, x: 0, y: 10)
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
