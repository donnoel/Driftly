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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    private var isPadLayout: Bool {
        horizontalSizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad
    }

    private var sectionHorizontalInset: CGFloat {
        isPadLayout ? 24 : 16
    }

    private func modeCardWidth(for section: DriftModeBrowseSection) -> CGFloat {
        if horizontalSizeClass == .regular {
            switch section {
            case .signature:
                return 388
            case .secondary:
                return 360
            case .labs:
                return 332
            }
        }

        switch section {
        case .signature:
            return 212
        case .secondary:
            return 196
        case .labs:
            return 182
        }
    }

    private func modeCardHeight(for section: DriftModeBrowseSection) -> CGFloat {
        if horizontalSizeClass == .regular {
            switch section {
            case .signature:
                return 232
            case .secondary:
                return 224
            case .labs:
                return 216
            }
        }

        switch section {
        case .signature:
            return 148
        case .secondary:
            return 142
        case .labs:
            return 136
        }
    }

    private var sceneCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 304 : 214
    }

    private var sceneCardHeight: CGFloat {
        horizontalSizeClass == .regular ? 174 : 146
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
        Section {
            VStack(alignment: .leading, spacing: isPadLayout ? 14 : 10) {
                scenesHeader

                if engine.availableScenes.isEmpty {
                    sceneEmptyCard
                        .frame(maxWidth: .infinity, minHeight: 106)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(engine.availableScenes) { scene in
                            sceneCard(for: scene)
                                .frame(width: sceneCardWidth, height: sceneCardHeight)
                        }
                        newSceneCard
                            .frame(width: sceneCardWidth, height: sceneCardHeight)
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 1)
                }
            }
            .padding(.top, isPadLayout ? 8 : 4)
        }
        .listRowInsets(.init(top: isPadLayout ? 8 : 2, leading: sectionHorizontalInset, bottom: isPadLayout ? 10 : 6, trailing: sectionHorizontalInset))
        .listRowBackground(Color.clear)
    }

    private var scenesHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Scenes")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text("Save ambient rituals for quick recall.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.68))
        }
    }

    private var sceneEmptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No Scenes Yet", systemImage: "sparkles.rectangle.stack")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Text("Create a scene to capture your current mood, favorites, and drift setup.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }

    private var newSceneCard: some View {
        Button {
            beginNewScene()
        } label: {
            SceneCreateCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("newSceneButton")
    }

    private func sceneCard(for scene: DriftScene) -> some View {
        let isActive = engine.activeSceneID == scene.id

        return Button {
            engine.activateScene(id: scene.id)
        } label: {
            SceneBrowseCard(
                name: scene.name,
                modeCount: scene.modeIDs.count,
                isActive: isActive
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Menu {
                Button {
                    beginEditing(scene)
                } label: {
                    Label("Edit Scene", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    engine.deleteScene(id: scene.id)
                } label: {
                    Label("Delete Scene", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.38))
                    )
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("Scene options")
        }
    }

    private var iosPicker: some View {
        NavigationStack {
            ZStack {
                pickerBackdrop

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
            }
            .navigationTitle("Select Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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

    private var pickerBackdrop: some View {
        ZStack {
            Color.black
            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear,
                    Color.white.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 22)
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.08))
        }
        .ignoresSafeArea()
    }

    private func sectionHeader(for section: DriftModeBrowseSection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section.title)
                .font(section == .signature ? .title3.weight(.bold) : .title3.weight(.semibold))
                .foregroundStyle(section == .labs ? Color.white.opacity(0.64) : Color.white)
            Text(section.subtitle)
                .font(.caption)
                .foregroundStyle(section == .labs ? Color.white.opacity(0.46) : Color.white.opacity(0.68))
        }
        .padding(.top, section == .signature ? (isPadLayout ? 12 : 8) : (isPadLayout ? 6 : 4))
        .textCase(nil)
    }

    private func modeRail(for group: ModeBrowseGroup) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: isPadLayout ? 18 : (horizontalSizeClass == .regular ? 16 : 12)) {
                ForEach(group.modes) { presentation in
                    modeCard(for: presentation)
                        .frame(
                            width: modeCardWidth(for: presentation.section),
                            height: modeCardHeight(for: presentation.section)
                        )
                }
            }
            .padding(.vertical, isPadLayout ? 6 : 4)
            .padding(.horizontal, 1)
        }
        .listRowInsets(.init(top: isPadLayout ? 6 : 2, leading: sectionHorizontalInset, bottom: isPadLayout ? 18 : 14, trailing: sectionHorizontalInset))
        .listRowBackground(Color.clear)
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
            VStack(alignment: .leading, spacing: 2) {
                Text("Scenes")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("Saved ambient rituals.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.68))
            }
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
                    .foregroundStyle(group.section == .labs ? Color.white.opacity(0.68) : Color.white)
                Text(group.section.subtitle)
                    .font(.caption)
                    .foregroundStyle(group.section == .labs ? Color.white.opacity(0.44) : Color.white.opacity(0.68))
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
            .scaleEffect(isFocused ? (reduceMotion ? 1.0 : 1.02) : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isFocused)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
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
        sceneEditorName = nextDefaultSceneName()
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

    private func nextDefaultSceneName() -> String {
        let baseName = "New Scene"
        let existingNames = Set(
            engine.availableScenes.map {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
        )

        if !existingNames.contains(baseName.lowercased()) {
            return baseName
        }

        var suffix = 2
        while existingNames.contains("\(baseName) \(suffix)".lowercased()) {
            suffix += 1
        }
        return "\(baseName) \(suffix)"
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
            .fill(cardFill)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(accentWash)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(glossFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(edgeColor, lineWidth: edgeWidth)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(innerEdgeColor, lineWidth: 0.7)
                    .padding(1.1)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(modeName)
                        .font(section == .signature ? .headline.weight(.bold) : .headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(descriptor)
                        .font(.caption)
                        .foregroundStyle(section == .labs ? Color.white.opacity(0.60) : Color.white.opacity(0.76))
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
                                .foregroundStyle(Color.yellow.opacity(0.92))
                        }
                    }
                }
                .padding(14)
            }
            .shadow(color: shadowColor, radius: isFocused ? 12 : 8, x: 0, y: isFocused ? 8 : 5)
            .opacity(section == .labs ? 0.78 : 1.0)
    }

    private var cardFill: LinearGradient {
        LinearGradient(
            colors: [
                palette.backgroundTop.opacity(isFocused ? 0.82 : (section == .labs ? 0.68 : 0.84)),
                palette.backgroundBottom.opacity(isFocused ? 0.92 : 0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accentWash: LinearGradient {
        LinearGradient(
            colors: [
                palette.primary.opacity(isFocused ? 0.18 : (section == .signature ? 0.26 : 0.20)),
                palette.secondary.opacity(isFocused ? 0.12 : (section == .labs ? 0.10 : 0.16)),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var glossFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(isFocused ? 0.10 : 0.05),
                Color.white.opacity(isFocused ? 0.03 : 0.015),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .center
        )
    }

    private var edgeColor: Color {
        if isFocused {
            return Color.white.opacity(0.42)
        }
        if isSelected {
            return Color.white.opacity(0.28)
        }
        return Color.white.opacity(section == .labs ? 0.12 : 0.18)
    }

    private var innerEdgeColor: Color {
        if isFocused {
            return palette.primary.opacity(0.42)
        }
        if isSelected {
            return palette.primary.opacity(0.22)
        }
        return Color.white.opacity(0.06)
    }

    private var edgeWidth: CGFloat {
        if isFocused {
            return 1.35
        }
        if isSelected {
            return 1.0
        }
        return 0.85
    }

    private var shadowColor: Color {
        if isFocused {
            return Color.black.opacity(0.34)
        }
        return Color.black.opacity(section == .labs ? 0.18 : 0.24)
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

    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedModeCount: Int {
        selection.count
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !selection.isEmpty
    }

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
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scene Name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("Enter scene name", text: $name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($isNameFocused)
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text("Pick a clear name so this scene is easy to find later.")
                }

                Section {
                    HStack(spacing: 10) {
                        Button("Select All") {
                            selection = Set(allModes)
                        }
                        .buttonStyle(.bordered)

                        Button("Clear") {
                            selection.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }

                    ForEach(allModes) { mode in
                        Toggle(mode.displayName, isOn: binding(for: mode))
                    }
                } header: {
                    HStack {
                        Text("Modes")
                        Spacer()
                        Text("\(selectedModeCount) selected")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
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
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if !isEditing {
                    DispatchQueue.main.async {
                        isNameFocused = true
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SceneBrowseCard: View {
    let name: String
    let modeCount: Int
    let isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isActive ? 0.24 : 0.14),
                        Color.white.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(isActive ? 0.46 : 0.22), lineWidth: isActive ? 1.6 : 1)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(modeCount) \(modeCount == 1 ? "mode" : "modes")")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.74))

                    if isActive {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.94))
                    }
                }
                .padding(14)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 6)
    }
}

private struct SceneCreateCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.26), lineWidth: 1.1)
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: 54, height: 54)
                    .blur(radius: 14)
                    .padding(10)
            }
            .overlay {
                VStack(alignment: .leading, spacing: 8) {
                    Label("New Scene", systemImage: "plus.circle.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("Capture this setup as a reusable ambient ritual.")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.74))
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(14)
            }
            .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 5)
    }
}
#endif
