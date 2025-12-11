import SwiftUI

struct DriftlySettingsView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss

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

                Section("Screen") {
                    Toggle("Stay Awake (Prevent Auto-Lock)", isOn: $engine.preventAutoLock)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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
}
