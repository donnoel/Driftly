import SwiftUI

struct DriftlySettingsView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("requestShowOnboarding") private var requestShowOnboarding: Bool = false

#if os(tvOS)
    private enum TVFocus: Hashable {
        case autoDriftEnabled
        case autoDriftShuffle
        case stayAwake
        case showClock
        case showHowTo
    }

    @FocusState private var tvFocus: TVFocus?

    private struct TVBoolRow: View {
        let title: String
        @Binding var isOn: Bool
        let id: TVFocus
        let focus: FocusState<TVFocus?>.Binding
        var accessibilityID: String? = nil

        private var isFocused: Bool { focus.wrappedValue == id }

        private var baseButton: some View {
            Button {
                isOn.toggle()
            } label: {
                HStack(spacing: 14) {
                    Text(title)
                    Spacer()
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.semibold))
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .foregroundStyle(isFocused ? Color.black : Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isFocused ? Color.white.opacity(0.96) : Color.white.opacity(0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isFocused ? Color.white.opacity(0.92) : Color.white.opacity(0.14), lineWidth: 1)
                        }
                )
                .animation(.easeInOut(duration: 0.12), value: isFocused)
            }
            .buttonStyle(.plain)
            .focused(focus, equals: id)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
        }

        var body: some View {
            Group {
                if let accessibilityID {
                    baseButton.accessibilityIdentifier(accessibilityID)
                } else {
                    baseButton
                }
            }
        }
    }
    private struct TVActionRow: View {
        let title: String
        let systemImage: String?
        let id: TVFocus
        let focus: FocusState<TVFocus?>.Binding
        var accessibilityID: String? = nil
        let action: () -> Void

        private var isFocused: Bool { focus.wrappedValue == id }

        private var baseButton: some View {
            Button {
                action()
            } label: {
                HStack(spacing: 14) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.headline.weight(.semibold))
                    }
                    Text(title)
                    Spacer()
                }
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .foregroundStyle(isFocused ? Color.black : Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isFocused ? Color.white.opacity(0.96) : Color.white.opacity(0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isFocused ? Color.white.opacity(0.92) : Color.white.opacity(0.14), lineWidth: 1)
                        }
                )
                .animation(.easeInOut(duration: 0.12), value: isFocused)
            }
            .buttonStyle(.plain)
            .focused(focus, equals: id)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
        }

        var body: some View {
            Group {
                if let accessibilityID {
                    baseButton.accessibilityIdentifier(accessibilityID)
                } else {
                    baseButton
                }
            }
        }
    }
#endif

    private let autoDriftOptions: [Int] = [1, 5, 10, 15, 30]

    var body: some View {
#if os(tvOS)
        tvSettings
#else
        iosSettings
#endif
    }

// MARK: - iOS
#if !os(tvOS)
    private var iosSettings: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.07, blue: 0.14),
                        Color(red: 0.09, green: 0.08, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Form {
                    Section("Animation") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Animation Speed")
                                .font(.subheadline.weight(.semibold))

                            HStack(spacing: 12) {
                                Text("Slower")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Slider(value: $engine.animationSpeed, in: 0.5...1.8, step: 0.05)
                                    .accessibilityIdentifier("animationSpeedSlider")
                                    .accessibilityLabel("Animation Speed")

                                Text("Faster")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Text(speedLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("animationSpeedLabel")
                                .accessibilityValue(speedLabel)
                        }

                    }

                    Section {
                        Toggle("Auto Drift Between Modes", isOn: $engine.autoDriftEnabled)
                        Toggle("Shuffle Order", isOn: $engine.autoDriftShuffleEnabled)

                        Picker("Drift From", selection: $engine.autoDriftSource) {
                            Text("All Modes").tag(AutoDriftSource.all)
                            Text("Favorites").tag(AutoDriftSource.favorites)
                            if let sceneID = engine.activeSceneID,
                               let scene = engine.availableScenes.first(where: { $0.id == sceneID }) {
                                Text("Scene: \(scene.name)").tag(AutoDriftSource.scene(sceneID))
                            }
                        }

                        Picker("Drift Every", selection: $engine.autoDriftIntervalMinutes) {
                            ForEach(autoDriftOptions, id: \.self) { minutes in
                                Text("\(minutes) minutes").tag(minutes)
                            }
                        }
                    } header: {
                        Text("Drifting")
                    } footer: {
                        Text("Configure how Driftly transitions between modes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Screen") {
                        Toggle("Stay Awake", isOn: $engine.preventAutoLock)
                        Toggle("Show Clock", isOn: $engine.clockEnabled)
                    }

                    Section("About") {
                        LabeledContent("Version", value: versionString)
                    }
                    Section("Help") {
                        Button {
                            requestShowOnboarding = true
                            dismiss()
                        } label: {
                            Label("Show How To", systemImage: "questionmark.circle")
                        }
                        .accessibilityIdentifier("showHowToButton")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
#endif

// MARK: - tvOS
#if os(tvOS)
    private var tvSettings: some View {
        ZStack {
            tvAmbientBackground

            NavigationStack {
                VStack(spacing: 18) {
                    tvIntroCard

                    Form {
                        Section("Animation") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Animation Speed")
                                    .font(.body.weight(.semibold))

                                Picker("", selection: $engine.animationSpeed) {
                                    Text("Gentle").tag(0.6)
                                    Text("Normal").tag(1.0)
                                    Text("Lively").tag(1.4)
                                }
                                .pickerStyle(.segmented)

                                Text(speedLabel)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("animationSpeedLabel")
                                    .focusable(false)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                        }

                        Section {
                            TVBoolRow(
                                title: "Auto Drift Between Modes",
                                isOn: $engine.autoDriftEnabled,
                                id: .autoDriftEnabled,
                                focus: $tvFocus
                            )
                            TVBoolRow(
                                title: "Shuffle Order",
                                isOn: $engine.autoDriftShuffleEnabled,
                                id: .autoDriftShuffle,
                                focus: $tvFocus
                            )

                            Picker("Drift From", selection: $engine.autoDriftSource) {
                                Text("All Modes").tag(AutoDriftSource.all)
                                Text("Favorites").tag(AutoDriftSource.favorites)
                                if let sceneID = engine.activeSceneID,
                                   let scene = engine.availableScenes.first(where: { $0.id == sceneID }) {
                                    Text("Scene: \(scene.name)").tag(AutoDriftSource.scene(sceneID))
                                }
                            }
                            .listRowBackground(Color.clear)

                            Picker("Drift Every", selection: $engine.autoDriftIntervalMinutes) {
                                ForEach(autoDriftOptions, id: \.self) { minutes in
                                    Text("\(minutes) minutes").tag(minutes)
                                }
                            }
                            .listRowBackground(Color.clear)
                        } header: {
                            Text("Drifting")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        } footer: {
                            Text("Configure how Driftly transitions between modes.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .focusable(false)
                        }

                        Section("Screen") {
                            TVBoolRow(
                                title: "Stay Awake",
                                isOn: $engine.preventAutoLock,
                                id: .stayAwake,
                                focus: $tvFocus
                            )
                            TVBoolRow(
                                title: "Show Clock",
                                isOn: $engine.clockEnabled,
                                id: .showClock,
                                focus: $tvFocus
                            )
                            Text("When a sleep timer ends, tvOS can show the screen saver or power down.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .focusable(false)
                                .listRowBackground(Color.clear)
                        }

                        Section("About") {
                            HStack {
                                Text("Version")
                                Spacer()
                                Text(versionString)
                            }
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    }
                            )
                            .contentShape(Rectangle())
                            .focusable(true)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                        }

                        Section("Help") {
                            TVActionRow(
                                title: "Show How To",
                                systemImage: "questionmark.circle",
                                id: .showHowTo,
                                focus: $tvFocus,
                                accessibilityID: "showHowToButton"
                            ) {
                                requestShowOnboarding = true
                                dismiss()
                            }
                        }
                    }
                    .frame(maxWidth: 980)
                    .background(Color.clear)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.black.opacity(0.28))
                            .overlay {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            }
                    )
                }
                .padding(.horizontal, 56)
                .padding(.vertical, 36)
                .navigationTitle("Settings")
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .onExitCommand { dismiss() }
        .preferredColorScheme(.dark)
    }

    private var tvAmbientBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.06),
                    Color(red: 0.04, green: 0.05, blue: 0.09),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 620
            )
            .blendMode(.screen)
            .offset(x: -160, y: -180)
        }
        .ignoresSafeArea()
    }

    private var tvIntroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))

                Text("Settings")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Text("Fine-tune how Driftly behaves on Apple TV.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.72))

            Text("Adjust animation, drifting, screen behavior, and help in one place.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.84))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
        )
    }
#endif

    private var speedLabel: String {
        speedDescriptor(for: effectiveAnimationSpeed)
    }

    private var effectiveAnimationSpeed: Double {
        DriftAnimationPolicy.effectiveSpeed(
            base: engine.animationSpeed,
            reduceMotion: reduceMotion,
            respectSystemReduceMotion: engine.respectSystemReduceMotion
        )
    }

    private func speedDescriptor(for speed: Double) -> String {
        switch speed {
        case ..<0.8: return "Gentle"
        case 0.8...1.2: return "Normal"
        default: return "Lively"
        }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
