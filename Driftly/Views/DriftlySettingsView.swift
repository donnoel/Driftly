import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DriftlySettingsView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss

    // Matches your existing settings file
    private let autoDriftOptions: [Int] = [1, 5, 10, 15, 30]

    var body: some View {
        #if os(tvOS)
        tvSettings
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
                Toggle("Show Clock Overlay", isOn: $engine.clockEnabled)
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

#if os(tvOS)
// MARK: - tvOS settings (Apple-style screen)

private var tvSettings: some View {
    ZStack {
        Color.black.ignoresSafeArea()

        NavigationStack {
            List {
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
                    }
                    .padding(.vertical, 8)
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
                Toggle("Show Clock Overlay", isOn: $engine.clockEnabled)
                Text("When a sleep timer ends, tvOS can show the screen saver or power down.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(versionString)
                            .foregroundStyle(.secondary)
                    }
                    .font(.headline)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .focusable(true)
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 72)
            .navigationTitle("Settings")
            .tint(.white)
            .onAppear {
                // Keep List backgrounds consistently dark on tvOS for legibility.
                UITableView.appearance().backgroundColor = .black
                UITableViewCell.appearance().backgroundColor = .black
            }
        }
    }
    // Match the Sleep Timer screen: dismiss via the tvOS Menu button.
    .onExitCommand {
        dismiss()
    }
    .preferredColorScheme(.dark)
}
#endif

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
