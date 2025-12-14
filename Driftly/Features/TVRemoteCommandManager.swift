import Foundation
#if os(tvOS)
import MediaPlayer
import AVFoundation
import Combine

/// Captures play/pause remote commands on tvOS so they control Driftly instead of system media.
@MainActor
final class TVRemoteCommandManager: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    private var playToken: Any?
    private var pauseToken: Any?
    private var toggleToken: Any?
    private var handler: (() -> Void)?

    func start(handler: @escaping () -> Void) {
        self.handler = handler

        let session = AVAudioSession.sharedInstance()
        // Ambient + mix should keep other audio playing while allowing remote commands.
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .unknown

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true

        playToken = center.playCommand.addTarget { [weak self] _ in
            self?.handler?()
            return .success
        }
        pauseToken = center.pauseCommand.addTarget { [weak self] _ in
            self?.handler?()
            return .success
        }
        toggleToken = center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.handler?()
            return .success
        }
    }

    func stop() {
        let center = MPRemoteCommandCenter.shared()
        if let playToken { center.playCommand.removeTarget(playToken) }
        if let pauseToken { center.pauseCommand.removeTarget(pauseToken) }
        if let toggleToken { center.togglePlayPauseCommand.removeTarget(toggleToken) }
        playToken = nil
        pauseToken = nil
        toggleToken = nil
        handler = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
    }
}
#endif
