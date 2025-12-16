import SwiftUI

struct DriftlySettingsView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss

    // Matches your existing settings file
    private let autoDriftOptions: [Int] = [5, 10, 15, 30]

    var body: some View {
        #if os(tvOS)
        tvWindow
        #else
        iosSettings
        #endif
    }

#if !os(tvOS)
// MARK: - iOS (unchanged behavior)

private var iosSettings: some View {
    NavigationStack {
        Form {
            Section("Animation") {
                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: $engine.animationSpeed, in: 0.5...1.8, step: 0.05) {
                        Text("Animation Speed")
                    } minimumValueLabel: {
                        Text("Slower").font(.caption2)
                    } maximumValueLabel: {
                        Text("Faster").font(.caption2)
                    }

                    Text(speedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Auto Drift") {
                Toggle("Auto Drift Between Modes", isOn: $engine.autoDriftEnabled)
                Toggle("Shuffle Order", isOn: $engine.autoDriftShuffleEnabled)
                Toggle("Use Favorites Only", isOn: $engine.autoDriftFavoritesOnly)
                    .disabled(engine.favoriteModes.isEmpty)

                Picker("Drift Every", selection: $engine.autoDriftIntervalMinutes) {
                    ForEach(autoDriftOptions, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
            }

            Section("Screen") {
                Toggle("Stay Awake", isOn: $engine.preventAutoLock)
            }

            Section("About") {
                LabeledContent("Version", value: versionString)
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

    // MARK: - tvOS windowed panel (no Done button)

    private var tvWindow: some View {
        ZStack {
            Color.black.opacity(0.70).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Settings")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("Press Menu to close")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.65))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        tvCard(title: "Animation") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Animation Speed")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.90))

                                Picker("", selection: $engine.animationSpeed) {
                                    Text("Gentle").tag(0.6)
                                    Text("Normal").tag(1.0)
                                    Text("Lively").tag(1.4)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 520)

                                Text(speedLabel)
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(0.70))
                            }
                        }

                        tvCard(title: "Auto Drift") {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Auto Drift Between Modes", isOn: $engine.autoDriftEnabled)
                                Toggle("Shuffle Order", isOn: $engine.autoDriftShuffleEnabled)

                                Toggle("Use Favorites Only", isOn: $engine.autoDriftFavoritesOnly)
                                    .disabled(engine.favoriteModes.isEmpty)
                                    .foregroundStyle(engine.favoriteModes.isEmpty ? .white.opacity(0.50) : .white)

                                Text("Drift Every")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.90))

                                Picker("", selection: $engine.autoDriftIntervalMinutes) {
                                    ForEach(autoDriftOptions, id: \.self) { minutes in
                                        Text("\(minutes) minutes").tag(minutes)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 520)
                            }
                        }

                        tvCard(title: "Screen") {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Stay Awake", isOn: $engine.preventAutoLock)
                                Text("Keeps Driftly awake while running.")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(0.70))
                            }
                        }

                        tvCard(title: "About") {
                            HStack {
                                Text("Version")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.90))
                                Spacer()
                                Text(versionString)
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white.opacity(0.70))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(36)
            .frame(maxWidth: 1040, maxHeight: 760)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.50), radius: 40, x: 0, y: 18)
            .padding(.horizontal, 40)
        }
        .preferredColorScheme(.dark)
    }

    private func tvCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)

            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var speedLabel: String {
        switch engine.animationSpeed {
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
