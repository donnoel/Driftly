import SwiftUI

struct DriftlyRootView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @State private var didAppear = false

    var body: some View {
        ZStack {
            // Lamp canvas
            activeModeView
                .ignoresSafeArea()

            // Minimal chrome (bottom overlay)
            if engine.isChromeVisible {
                VStack {
                    Spacer()
                    bottomChrome
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 32)
                        .padding(.horizontal, 24)
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.35)) {
                engine.isChromeVisible.toggle()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                didAppear = true
            }
        }
    }

    @ViewBuilder
    private var activeModeView: some View {
        switch engine.currentMode {
        case .nebulaLake:
            NebulaLakeView(config: engine.currentMode.config)
        case .cosmicTide:
            CosmicTideView(config: engine.currentMode.config)
        default:
            // For now, fall back to Nebula Lake for unimplemented modes
            NebulaLakeView(config: engine.currentMode.config)
        }
    }

    private var bottomChrome: some View {
        HStack(spacing: 16) {
            // Left: current mode
            VStack(alignment: .leading, spacing: 4) {
                Text(engine.currentMode.displayName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Text("Tap anywhere to hide controls")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            // Right: tiny buttons
            HStack(spacing: 12) {
                CircleButton(systemName: "sparkles") {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        engine.goToNextMode()
                    }
                }

                CircleButton(systemName: "moon.zzz") {
                    // future: sleep timer
                }

                CircleButton(systemName: "gearshape") {
                    // future: settings / options
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.35))
                .blur(radius: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.08))
                )
        )
    }
}

private struct CircleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(.black.opacity(0.45))
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.12))
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
