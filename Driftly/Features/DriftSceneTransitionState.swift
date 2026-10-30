import Foundation

/// Only scene identity starts a dissolve; live speed controls update the current renderer in place.
struct DriftScenePresentation: Equatable {
    struct Identity: Equatable {
        let mode: DriftMode
        let sceneID: UUID?
    }

    let mode: DriftMode
    let sceneID: UUID?
    let animationSpeed: Double

    var identity: Identity { Identity(mode: mode, sceneID: sceneID) }
}

/// Retains renderer identities and outgoing settings until a blend actually completes.
struct DriftSceneTransitionState {
    struct Layer: Identifiable, Equatable {
        let id: UUID
        var presentation: DriftScenePresentation
    }

    private(set) var layers: [Layer]
    private(set) var transitionID: UUID?
    private(set) var pendingPresentation: DriftScenePresentation?

    init(presentation: DriftScenePresentation) {
        layers = [Layer(id: UUID(), presentation: presentation)]
    }

    /// While blending, coalesce rapid selections to the latest request. Never add a third renderer.
    @discardableResult
    mutating func request(
        _ presentation: DriftScenePresentation,
        animated: Bool,
        preparedLayerID: UUID? = nil
    ) -> UUID? {
        if !animated {
            let matchingID = layers.last(where: { $0.presentation.identity == presentation.identity })?.id
            layers = [Layer(id: matchingID ?? preparedLayerID ?? UUID(), presentation: presentation)]
            transitionID = nil
            pendingPresentation = nil
            return nil
        }

        guard transitionID == nil else {
            if layers.last?.presentation.identity == presentation.identity {
                // Live controls remain responsive on the incoming scene, even during its fade.
                layers[layers.count - 1].presentation = presentation
                pendingPresentation = nil
            } else {
                pendingPresentation = presentation
            }
            return nil
        }

        if layers[0].presentation.identity == presentation.identity {
            layers[0].presentation = presentation
            return nil
        }

        layers.append(Layer(id: preparedLayerID ?? UUID(), presentation: presentation))
        let id = UUID()
        transitionID = id
        return id
    }

    /// A generation token prevents an interrupted or repeated A → B → A completion from clearing new work.
    mutating func complete(_ id: UUID) -> DriftScenePresentation? {
        guard transitionID == id, let incoming = layers.last else { return nil }
        layers = [incoming]
        transitionID = nil
        let pending = pendingPresentation
        pendingPresentation = nil
        return pending
    }
}
