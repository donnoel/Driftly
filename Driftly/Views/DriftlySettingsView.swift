import SwiftUI

struct DriftlySettingsView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss

    // Preset intervals we expose in the UI
    private let autoDriftOptions: [Int] = [5, 10, 15, 30]

    var body: some View {
        NavigationStack {
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

#if os(tvOS)
                        Picker("Animation Speed", selection: $engine.animationSpeed) {
                            Text("Gentle").tag(0.6)
                            Text("Normal").tag(1.0)
                            Text("Lively").tag(1.4)
                        }
                        .pickerStyle(.segmented)
#else
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
#endif
                    }
                }

                Section("Auto Drift") {
                    Toggle("Auto Drift Between Modes", isOn: $engine.autoDriftEnabled)

                    Toggle("Shuffle Order", isOn: $engine.autoDriftShuffleEnabled)

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
            .navigationTitle("Settings")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

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
