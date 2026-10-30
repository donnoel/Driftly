import Foundation
import Testing
@testable import Driftly

@MainActor
struct ModeViewBuilderTests {

    @Test func coversAllModes() async throws {
        let builders = ModeViewRegistry.builders
        #expect(builders.count == DriftMode.allCases.count)

        for mode in DriftMode.allCases {
            #expect(builders[mode] != nil, "Missing builder for \(mode.rawValue)")
        }
    }
}

@MainActor
struct DriftSceneTransitionStateTests {

    @Test func initialPresentationHasOneStableRenderer() {
        let initial = presentation(.auroraVeil)
        let state = DriftSceneTransitionState(presentation: initial)

        #expect(state.layers.map(\.presentation) == [initial])
        #expect(state.transitionID == nil)
        #expect(state.pendingPresentation == nil)
    }

    @Test func animatedRequestPreservesOutgoingRendererAndItsSpeed() throws {
        let outgoing = presentation(.auroraVeil, speed: 0.6)
        let incoming = presentation(.plasmaReef, speed: 1.4)
        var state = DriftSceneTransitionState(presentation: outgoing)
        let outgoingLayerID = try #require(state.layers.first?.id)

        let requestedTransitionID = state.request(incoming, animated: true)
        let transitionID = try #require(requestedTransitionID)

        #expect(state.layers.map(\.presentation) == [outgoing, incoming])
        #expect(state.layers.first?.id == outgoingLayerID)
        #expect(state.layers.last?.id != outgoingLayerID)
        #expect(state.transitionID == transitionID)
        let incomingLayerID = try #require(state.layers.last?.id)

        let pending = state.complete(transitionID)
        #expect(pending == nil)
        #expect(state.layers.map(\.presentation) == [incoming])
        #expect(state.layers.first?.id == incomingLayerID)
        #expect(state.transitionID == nil)
    }

    @Test func savedScenesUsingTheSameModeStillTransition() throws {
        let firstScene = presentation(.auroraVeil, sceneID: UUID(), speed: 0.7)
        let secondScene = presentation(.auroraVeil, sceneID: UUID(), speed: 1.2)
        var state = DriftSceneTransitionState(presentation: firstScene)

        #expect(firstScene.identity != secondScene.identity)
        let requestedTransitionID = state.request(secondScene, animated: true)
        let transitionID = try #require(requestedTransitionID)

        #expect(state.layers.map(\.presentation) == [firstScene, secondScene])
        #expect(state.layers[0].id != state.layers[1].id)
        #expect(state.transitionID == transitionID)
    }

    @Test func speedOnlyChangeUpdatesTheExistingRendererWithoutFading() throws {
        let sceneID = UUID()
        let initial = presentation(.auroraVeil, sceneID: sceneID, speed: 0.6)
        let updated = presentation(.auroraVeil, sceneID: sceneID, speed: 1.3)
        var state = DriftSceneTransitionState(presentation: initial)
        let rendererID = try #require(state.layers.first?.id)

        #expect(initial.identity == updated.identity)
        let transitionID = state.request(updated, animated: true)
        #expect(transitionID == nil)

        #expect(state.layers.map(\.presentation) == [updated])
        #expect(state.layers.first?.id == rendererID)
        #expect(state.transitionID == nil)
        #expect(state.pendingPresentation == nil)
    }

    @Test func liveSpeedChangePreservesOutgoingAndCancelsAnObsoleteQueuedChoice() throws {
        let outgoing = presentation(.auroraVeil, speed: 0.6)
        let incoming = presentation(.plasmaReef, speed: 1.1)
        let obsoleteChoice = presentation(.glassTides)
        let updatedIncoming = presentation(.plasmaReef, speed: 1.4)
        var state = DriftSceneTransitionState(presentation: outgoing)
        let requestedTransitionID = state.request(incoming, animated: true)
        let transitionID = try #require(requestedTransitionID)
        let rendererIDs = state.layers.map(\.id)
        let queuedTransitionID = state.request(obsoleteChoice, animated: true)
        #expect(queuedTransitionID == nil)
        #expect(state.pendingPresentation == obsoleteChoice)

        let updatedTransitionID = state.request(updatedIncoming, animated: true)

        #expect(updatedTransitionID == nil)
        #expect(state.transitionID == transitionID)
        #expect(state.layers.map(\.id) == rendererIDs)
        #expect(state.layers.map(\.presentation) == [outgoing, updatedIncoming])
        #expect(state.pendingPresentation == nil)
        let nextPresentation = state.complete(transitionID)
        #expect(nextPresentation == nil)
        #expect(state.layers.map(\.presentation) == [updatedIncoming])
        #expect(state.layers.first?.id == rendererIDs.last)
    }

    @Test func rapidChoicesKeepOnlyTheLatestPendingPresentation() throws {
        let first = presentation(.auroraVeil)
        let second = presentation(.plasmaReef)
        let intermediate = presentation(.glassTides)
        let latest = presentation(.starlitMist, speed: 0.8)
        var state = DriftSceneTransitionState(presentation: first)
        let requestedTransitionID = state.request(second, animated: true)
        let transitionID = try #require(requestedTransitionID)
        let activeLayers = state.layers
        let secondLayerID = try #require(state.layers.last?.id)

        let intermediateTransitionID = state.request(intermediate, animated: true)
        let latestTransitionID = state.request(latest, animated: true)
        #expect(intermediateTransitionID == nil)
        #expect(latestTransitionID == nil)

        #expect(state.layers == activeLayers)
        #expect(state.layers.count == 2)
        #expect(state.transitionID == transitionID)
        #expect(state.pendingPresentation == latest)
        let nextPresentation = state.complete(transitionID)
        #expect(nextPresentation == latest)
        #expect(state.layers.map(\.presentation) == [second])
        #expect(state.layers.first?.id == secondLayerID)
        #expect(state.pendingPresentation == nil)

        let requestedNextTransitionID = state.request(latest, animated: true)
        let nextTransitionID = try #require(requestedNextTransitionID)
        #expect(nextTransitionID != transitionID)
        #expect(state.layers.map(\.presentation) == [second, latest])
        #expect(state.layers.first?.id == secondLayerID)
    }

    @Test func repeatedModesCannotBeRemovedByAnEarlierCompletion() throws {
        let first = presentation(.auroraVeil)
        let second = presentation(.plasmaReef)
        var state = DriftSceneTransitionState(presentation: first)
        let requestedFirstTransitionID = state.request(second, animated: true)
        let firstTransitionID = try #require(requestedFirstTransitionID)
        let firstCompletion = state.complete(firstTransitionID)
        #expect(firstCompletion == nil)

        let requestedReturnTransitionID = state.request(first, animated: true)
        let returnTransitionID = try #require(requestedReturnTransitionID)
        let returningLayers = state.layers
        #expect(returnTransitionID != firstTransitionID)

        let staleFirstCompletion = state.complete(firstTransitionID)
        #expect(staleFirstCompletion == nil)
        #expect(state.layers == returningLayers)
        #expect(state.transitionID == returnTransitionID)

        let returnCompletion = state.complete(returnTransitionID)
        #expect(returnCompletion == nil)
        #expect(state.layers.map(\.presentation) == [first])
        let requestedRepeatTransitionID = state.request(second, animated: true)
        let repeatTransitionID = try #require(requestedRepeatTransitionID)
        let repeatingLayers = state.layers

        #expect(repeatTransitionID != firstTransitionID)
        let staleRepeatedCompletion = state.complete(firstTransitionID)
        let staleReturnCompletion = state.complete(returnTransitionID)
        #expect(staleRepeatedCompletion == nil)
        #expect(staleReturnCompletion == nil)
        #expect(state.layers == repeatingLayers)
        #expect(state.transitionID == repeatTransitionID)
    }

    @Test func nonanimatedChangeCancelsPendingWorkAndReusesMatchingRenderer() throws {
        let first = presentation(.auroraVeil)
        let second = presentation(.plasmaReef)
        let pending = presentation(.glassTides)
        let updatedSecond = presentation(.plasmaReef, speed: 1.4)
        var state = DriftSceneTransitionState(presentation: first)
        let requestedTransitionID = state.request(second, animated: true)
        let transitionID = try #require(requestedTransitionID)
        let secondLayerID = try #require(state.layers.last?.id)
        let pendingTransitionID = state.request(pending, animated: true)
        #expect(pendingTransitionID == nil)

        let snappedTransitionID = state.request(updatedSecond, animated: false)
        #expect(snappedTransitionID == nil)

        #expect(state.layers.map(\.presentation) == [updatedSecond])
        #expect(state.layers.first?.id == secondLayerID)
        #expect(state.transitionID == nil)
        #expect(state.pendingPresentation == nil)
        let snappedLayers = state.layers
        let obsoleteCompletion = state.complete(transitionID)
        #expect(obsoleteCompletion == nil)
        #expect(state.layers == snappedLayers)
    }

    @Test func preparedRendererIsPromotedWithoutChangingItsIdentity() throws {
        let initial = presentation(.auroraVeil)
        let incoming = presentation(.plasmaReef)
        let preparedLayerID = UUID()
        var state = DriftSceneTransitionState(presentation: initial)

        let requestedTransitionID = state.request(incoming, animated: true, preparedLayerID: preparedLayerID)
        let transitionID = try #require(requestedTransitionID)

        #expect(state.layers.last?.id == preparedLayerID)
        let pending = state.complete(transitionID)
        #expect(pending == nil)
        #expect(state.layers.map(\.presentation) == [incoming])
        #expect(state.layers.first?.id == preparedLayerID)
    }

    private func presentation(
        _ mode: DriftMode,
        sceneID: UUID? = nil,
        speed: Double = 1
    ) -> DriftScenePresentation {
        DriftScenePresentation(mode: mode, sceneID: sceneID, animationSpeed: speed)
    }
}
