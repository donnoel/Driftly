import SwiftUI

struct DriftlySettingsView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss

    // Preset intervals we expose in the UI
    private let autoDriftOptions: [Int] = [1, 5, 10, 15, 30]

    var body: some View {
        NavigationStack {
            settingsContent
                .navigationTitle("Settings")
#if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
#if os(tvOS)
                    .font(.system(size: 20, weight: .semibold))
#endif
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var settingsContent: some View {
#if os(tvOS)
        tvSettings
#else
        iosSettings
#endif
    }

#if os(tvOS)
    private var tvSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Animation
                VStack(alignment: .leading, spacing: 12) {
                    Text("Animation")
                        .font(.title2.weight(.semibold))
                    Text("Animation Speed")
                        .font(.headline)
                    Picker("", selection: $engine.animationSpeed) {
                        Text("Gentle").tag(0.6)
                        Text("Normal").tag(1.0)
                        Text("Lively").tag(1.4)
                    }
                    .pickerStyle(.segmented)
                    Text(speedLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Auto Drift
                VStack(alignment: .leading, spacing: 12) {
                    Text("Auto Drift")
                        .font(.title2.weight(.semibold))
                    Toggle("Auto Drift Between Modes", isOn: $engine.autoDriftEnabled)
                    Toggle("Shuffle Order", isOn: $engine.autoDriftShuffleEnabled)
                    Toggle("Use Favorites Only", isOn: $engine.autoDriftFavoritesOnly)
                        .disabled(engine.favoriteModes.isEmpty)
                        .foregroundStyle(engine.favoriteModes.isEmpty ? .secondary : .primary)
                    Text("Drift Every")
                        .font(.headline)
                    Picker("", selection: $engine.autoDriftIntervalMinutes) {
                        ForEach(autoDriftOptions, id: \.self) { minutes in
                            Text("\(minutes) minutes")
                                .tag(minutes)
                        }
                    }
                    .pickerStyle(.inline)
                    .disabled(!engine.autoDriftEnabled)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Screen
                VStack(alignment: .leading, spacing: 12) {
                    Text("Screen")
                        .font(.title2.weight(.semibold))
                    Toggle("Stay Awake", isOn: $engine.preventAutoLock)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // About
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.title2.weight(.semibold))
                    LabeledContent("Version", value: versionString)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .font(.system(size: 20))
        }
        .background(Color.black.opacity(0.85).ignoresSafeArea())
    }
#else
    private var iosSettings: some View {
        Form {
            Section("Animation") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Animation Speed")
                        Spacer()
                        Text(speedLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: $engine.animationSpeed,
                        in: 0.5...1.5
                    ) {
                        Text("Animation Speed")
                    } minimumValueLabel: {
                        Text("Slower")
                            .font(.caption2)
                    } maximumValueLabel: {
                        Text("Faster")
                            .font(.caption2)
                    }
                }
            }

            Section("Auto Drift") {
                Toggle("Auto Drift Between Modes", isOn: $engine.autoDriftEnabled)

                Toggle("Shuffle Order", isOn: $engine.autoDriftShuffleEnabled)

                Toggle("Use Favorites Only", isOn: $engine.autoDriftFavoritesOnly)
                    .disabled(engine.favoriteModes.isEmpty)
                    .foregroundStyle(engine.favoriteModes.isEmpty ? .secondary : .primary)

                Picker("Drift Every", selection: $engine.autoDriftIntervalMinutes) {
                    ForEach(autoDriftOptions, id: \.self) { minutes in
                        Text("\(minutes) minutes")
                            .tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!engine.autoDriftEnabled)
            }

            Section("Screen") {
                Toggle("Stay Awake", isOn: $engine.preventAutoLock)
            }

            Section("About") {
                LabeledContent("Version", value: versionString)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
#endif

    private var speedLabel: String {
        switch engine.animationSpeed {
        case ..<0.8:
            return "Gentle"
        case 0.8...1.2:
            return "Normal"
        default:
            return "Lively"
        }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
