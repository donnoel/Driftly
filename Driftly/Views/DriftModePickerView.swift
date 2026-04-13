import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DriftModePickerView: View {
    @EnvironmentObject private var engine: DriftlyEngine
    @Environment(\.dismiss) private var dismiss
    @State private var isSceneEditorPresented = false
    @State private var sceneEditorSelection: Set<DriftMode> = []
    @State private var sceneEditorName: String = ""
    @State private var editingSceneID: UUID?
#if !os(tvOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
#if os(tvOS)
    @FocusState private var focusedMode: DriftMode?
#endif

    private var modeGroups: [ModeBrowseGroup] {
        DriftModeBrowseSection.allCases.compactMap { section in
            let modes = DriftModePresentationCatalog.presentations(
                from: engine.modePickerModes,
                section: section
            )
            guard !modes.isEmpty else { return nil }
            return ModeBrowseGroup(section: section, modes: modes)
        }
    }

#if !os(tvOS)
    private var modeCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 296 : 236
    }

    private var modeCardHeight: CGFloat {
        horizontalSizeClass == .regular ? 182 : 162
    }
#endif

    var body: some View {
#if os(tvOS)
        tvWindow
#else
        iosPicker
#endif
    }

#if !os(tvOS)
    @ViewBuilder
    private var scenesSection: some View {
        Section("Scenes") {
            if engine.availableScenes.isEmpty {
                Text("Capture a set of modes and settings as a Scene.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(engine.availableScenes) { scene in
                    SceneRow(
                        scene: scene,
                        isActive: engine.activeSceneID == scene.id,
                        onActivate: { engine.activateScene(id: scene.id) },
                        onEdit: { beginEditing(scene) },
                        onDelete: { engine.deleteScene(id: scene.id) }
                    )
                }
            }

            Button {
                beginNewScene()
            } label: {
                Label("New Scene", systemImage: "plus")
            }
            .accessibilityIdentifier("newSceneButton")
        }
    }

    private var iosPicker: some View {
        NavigationStack {
            List {
                scenesSection

                ForEach(modeGroups) { group in
                    Section {
                        modeRail(for: group)
                    } header: {
                        sectionHeader(for: group.section)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("modePickerSheet")
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Select Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: AppShare.appStoreURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("modePickerShareButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isSceneEditorPresented) {
            SceneEditorView(
                name: $sceneEditorName,
                selection: $sceneEditorSelection,
                allModes: engine.modePickerModes,
                isEditing: editingSceneID != nil,
                onSave: {
                    let ordered = engine.modeDisplayOrder.filter { sceneEditorSelection.contains($0) }
                    if let editingSceneID {
                        engine.updateScene(id: editingSceneID, name: sceneEditorName, modeIDs: ordered)
                        if engine.activeSceneID == editingSceneID {
                            engine.activateScene(id: editingSceneID)
                        }
                    } else {
                        engine.createScene(name: sceneEditorName, modeIDs: ordered)
                    }
                    isSceneEditorPresented = false
                    editingSceneID = nil
                },
                onCancel: {
                    isSceneEditorPresented = false
                    editingSceneID = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func sectionHeader(for section: DriftModeBrowseSection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section.title)
                .font(section == .signature ? .title3.weight(.bold) : .title3.weight(.semibold))
                .foregroundStyle(section == .labs ? Color.white.opacity(0.74) : Color.white)
            Text(section.subtitle)
                .font(.caption)
                .foregroundStyle(section == .labs ? Color.white.opacity(0.55) : Color.white.opacity(0.68))
        }
        .textCase(nil)
    }

    private func modeRail(for group: ModeBrowseGroup) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(group.modes) { presentation in
                    modeCard(for: presentation)
                        .frame(width: modeCardWidth, height: modeCardHeight)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .listRowInsets(.init(top: 4, leading: 18, bottom: 10, trailing: 18))
        .listRowBackground(Color.black)
    }

    private func modeCard(for presentation: DriftModePresentation) -> some View {
        let mode = presentation.mode
        let isFavorite = engine.favoriteModes.contains(mode)

        return Button {
            selectMode(mode)
        } label: {
            ModeBrowserCard(
                modeName: mode.displayName,
                descriptor: presentation.descriptor,
                palette: mode.config.palette,
                section: presentation.section,
                isSelected: mode == engine.currentMode,
                isFavorite: isFavorite,
                isFocused: false
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            favoriteBadgeButton(mode: mode, isFavorite: isFavorite)
        }
        .accessibilityIdentifier("modeRow-\(mode.rawValue)")
    }

    private func favoriteBadgeButton(mode: DriftMode, isFavorite: Bool) -> some View {
        Button {
            engine.toggleFavorite(mode)
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.yellow : Color.white.opacity(0.84))
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.42))
                )
        }
        .buttonStyle(.plain)
        .padding(10)
        .accessibilityIdentifier("favorite-\(mode.rawValue)")
        .accessibilityLabel(isFavorite ? "Unfavorite" : "Favorite")
    }
#endif

#if os(tvOS)
    private var tvWindow: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        if !engine.availableScenes.isEmpty {
                            tvScenesSection
                        }

                        ForEach(modeGroups) { group in
                            tvModeRail(for: group)
                        }

                        Text("Tip: Press Play/Pause to add or remove a favorite.")
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.7))
                            .padding(.horizontal, 64)
                    }
                    .padding(.vertical, 44)
                }
                .navigationTitle("Select Mode")
            }
        }
        .onAppear {
            if focusedMode == nil {
                focusedMode = modeGroups
                    .first(where: { $0.section == .signature })?
                    .modes
                    .first?
                    .mode
                    ?? modeGroups.first?.modes.first?.mode
            }
        }
        .onPlayPauseCommand {
            if let focusedMode {
                engine.toggleFavorite(focusedMode)
            }
        }
        .onExitCommand {
            dismiss()
        }
        .preferredColorScheme(.dark)
    }

    private var tvScenesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scenes")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 64)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(engine.availableScenes) { scene in
                        Button {
                            engine.activateScene(id: scene.id)
                        } label: {
                            HStack(spacing: 10) {
                                Text(scene.name)
                                    .font(.headline)
                                if engine.activeSceneID == scene.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.headline)
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(engine.activeSceneID == scene.id ? 0.18 : 0.10))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 64)
            }
        }
    }

    private func tvModeRail(for group: ModeBrowseGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(group.section.title)
                    .font(group.section == .signature ? .title2.weight(.bold) : .title3.weight(.semibold))
                    .foregroundStyle(group.section == .labs ? Color.white.opacity(0.74) : Color.white)
                Text(group.section.subtitle)
                    .font(.caption)
                    .foregroundStyle(group.section == .labs ? Color.white.opacity(0.54) : Color.white.opacity(0.68))
            }
            .padding(.horizontal, 64)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(group.modes) { presentation in
                        tvModeCard(for: presentation)
                    }
                }
                .padding(.horizontal, 64)
                .padding(.vertical, 6)
            }
        }
    }

    private func tvModeCard(for presentation: DriftModePresentation) -> some View {
        let mode = presentation.mode
        let isFocused = focusedMode == mode
        let isFavorite = engine.favoriteModes.contains(mode)

        let width: CGFloat
        switch presentation.section {
        case .signature:
            width = 430
        case .secondary:
            width = 390
        case .labs:
            width = 360
        }

        return Button {
            selectMode(mode)
        } label: {
            ModeBrowserCard(
                modeName: mode.displayName,
                descriptor: presentation.descriptor,
                palette: mode.config.palette,
                section: presentation.section,
                isSelected: mode == engine.currentMode,
                isFavorite: isFavorite,
                isFocused: isFocused
            )
            .frame(width: width, height: 232)
            .scaleEffect(isFocused ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .focused($focusedMode, equals: mode)
        .accessibilityIdentifier("mode-\(mode.rawValue)")
        .contextMenu {
            Button {
                engine.toggleFavorite(mode)
            } label: {
                Label(
                    isFavorite ? "Remove Favorite" : "Add Favorite",
                    systemImage: isFavorite ? "star.slash" : "star"
                )
            }
        }
    }
#endif

    private func selectMode(_ mode: DriftMode) {
        engine.currentMode = mode
        dismiss()
    }

    private func beginNewScene() {
        sceneEditorName = "Scene \(engine.availableScenes.count + 1)"
        sceneEditorSelection = Set(engine.modeDisplayOrder)
        editingSceneID = nil
        isSceneEditorPresented = true
    }

    private func beginEditing(_ scene: DriftScene) {
        sceneEditorName = scene.name
        sceneEditorSelection = Set(scene.modeIDs)
        editingSceneID = scene.id
        isSceneEditorPresented = true
    }
}

private struct ModeBrowseGroup: Identifiable {
    let section: DriftModeBrowseSection
    let modes: [DriftModePresentation]

    var id: DriftModeBrowseSection { section }
}

private struct ModeBrowserCard: View {
    let modeName: String
    let descriptor: String
    let palette: DriftPalette
    let section: DriftModeBrowseSection
    let isSelected: Bool
    let isFavorite: Bool
    let isFocused: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.backgroundTop.opacity(section == .labs ? 0.70 : 0.90),
                        palette.backgroundBottom.opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.primary.opacity(section == .signature ? 0.38 : 0.28),
                                palette.secondary.opacity(section == .labs ? 0.18 : 0.24),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(modeName)
                        .font(section == .signature ? .headline.weight(.bold) : .headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(descriptor)
                        .font(.caption)
                        .foregroundStyle(section == .labs ? Color.white.opacity(0.62) : Color.white.opacity(0.78))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if isSelected {
                            Label("Now Playing", systemImage: "checkmark.circle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        if isFavorite {
                            Label("Favorite", systemImage: "star.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.yellow.opacity(0.95))
                        }
                    }
                }
                .padding(14)
            }
            .shadow(color: shadowColor, radius: 14, x: 0, y: 8)
            .opacity(section == .labs ? 0.86 : 1.0)
    }

    private var borderColor: Color {
        if isFocused {
            return .white
        }
        if isSelected {
            return Color.white.opacity(0.84)
        }
        return Color.white.opacity(section == .labs ? 0.18 : 0.28)
    }

    private var borderWidth: CGFloat {
        if isFocused {
            return 2.4
        }
        if isSelected {
            return 1.7
        }
        return 1.0
    }

    private var shadowColor: Color {
        if isFocused {
            return palette.primary.opacity(0.34)
        }
        return palette.primary.opacity(section == .labs ? 0.12 : 0.20)
    }
}

#if !os(tvOS)
private struct SceneEditorView: View {
    @Binding var name: String
    @Binding var selection: Set<DriftMode>
    let allModes: [DriftMode]
    let isEditing: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    private func binding(for mode: DriftMode) -> Binding<Bool> {
        Binding {
            selection.contains(mode)
        } set: { newValue in
            if newValue {
                selection.insert(mode)
            } else {
                selection.remove(mode)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Scene name", text: $name)
                }

                Section("Modes") {
                    ForEach(allModes) { mode in
                        Toggle(mode.displayName, isOn: binding(for: mode))
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Scene" : "New Scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selection.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SceneRow: View {
    let scene: DriftScene
    let isActive: Bool
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            onActivate()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.name)
                        .font(.headline)
                    Text("\(scene.modeIDs.count) modes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }
}
#endif
