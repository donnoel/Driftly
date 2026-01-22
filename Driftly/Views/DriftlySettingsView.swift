import SwiftUI

struct DriftlySettingsView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("requestShowOnboarding") private var requestShowOnboarding: Bool = false

#if os(tvOS)
    private enum TVFocus: Hashable {
        case respectReduceMotion
        case labsEnabled
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
                .padding(.vertical, 6)
                // Critical: invert text under the focus pill
                .foregroundStyle(isFocused ? Color.black : Color.white)
                .animation(.easeInOut(duration: 0.12), value: isFocused)
            }
            .buttonStyle(.plain)
            .focused(focus, equals: id)
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
                .padding(.vertical, 6)
                // Critical: invert text under the focus pill
                .foregroundStyle(isFocused ? Color.black : Color.white)
                .animation(.easeInOut(duration: 0.12), value: isFocused)
            }
            .buttonStyle(.plain)
            .focused(focus, equals: id)
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

                    Toggle("Use System Reduce Motion", isOn: $engine.respectSystemReduceMotion)
                        .accessibilityIdentifier("respectReduceMotionToggle")

                    if let notice = reduceMotionNotice {
                        Text(notice)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("reduceMotionNotice")
                    }
                }

                Section {
                    Toggle("Enable Labs Features", isOn: $engine.labsFeaturesEnabled)

                    if engine.labsFeaturesEnabled {
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
                    }
                } header: {
                    Text("Labs")
                } footer: {
                    Text("Labs features may affect performance or behavior.")
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
            Color.black.ignoresSafeArea()

            NavigationStack {
                Form {
                    Section("Animation") {
                        VStack(alignment: .leading, spacing: 10) {
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
                        .padding(.vertical, 8)

                        TVBoolRow(
                            title: "Use System Reduce Motion",
                            isOn: $engine.respectSystemReduceMotion,
                            id: .respectReduceMotion,
                            focus: $tvFocus,
                            accessibilityID: "respectReduceMotionToggle"
                        )

                        if let notice = reduceMotionNotice {
                            Text(notice)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("reduceMotionNotice")
                                .focusable(false)
                        }
                    }

                    Section {
                        TVBoolRow(
                            title: "Enable Labs Features",
                            isOn: $engine.labsFeaturesEnabled,
                            id: .labsEnabled,
                            focus: $tvFocus
                        )

                        if engine.labsFeaturesEnabled {
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

                            Picker("Drift Every", selection: $engine.autoDriftIntervalMinutes) {
                                ForEach(autoDriftOptions, id: \.self) { minutes in
                                    Text("\(minutes) minutes").tag(minutes)
                                }
                            }
                        }
                    } header: {
                        Text("Labs")
                    } footer: {
                        Text("Labs features may affect performance or behavior.")
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
                    }

                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(versionString)
                        }
                        .font(.headline)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .focusable(true)
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
                .background(Color.black)
                .navigationTitle("Settings")
            }
        }
        .onExitCommand { dismiss() }
        .preferredColorScheme(.dark)
    }
#endif

    private var speedLabel: String {
        speedDescriptor(for: effectiveAnimationSpeed)
    }

    private var reduceMotionNotice: String? {
        guard reduceMotion else { return nil }
        if engine.respectSystemReduceMotion {
            return "System Reduce Motion is on; animations are softened."
        } else {
            return "System Reduce Motion is on, but Driftly will keep full animation speed."
        }
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
