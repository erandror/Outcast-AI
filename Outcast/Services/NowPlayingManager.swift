//
//  NowPlayingManager.swift
//  Outcast
//
//  Manages Now Playing info and remote command handling
//

import MediaPlayer
import UIKit

/// Manages lock screen Now Playing info and remote controls
@MainActor
class NowPlayingManager {
    
    static let shared = NowPlayingManager()
    
    private let commandCenter = MPRemoteCommandCenter.shared()
    private let nowPlayingInfo = MPNowPlayingInfoCenter.default()
    
    private init() {
        setupRemoteCommands()
    }
    
    // MARK: - Setup Remote Commands
    
    private func setupRemoteCommands() {
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                try? await PlaybackManager.shared.play()
            }
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            PlaybackManager.shared.pause()
            return .success
        }
        
        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            PlaybackManager.shared.togglePlayPause()
            return .success
        }
        
        // Skip forward
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            Task { @MainActor in
                if let skipEvent = event as? MPSkipIntervalCommandEvent {
                    await PlaybackManager.shared.skipForward(by: skipEvent.interval)
                } else {
                    await PlaybackManager.shared.skipForward(by: 15)
                }
            }
            return .success
        }
        
        // Skip backward
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            Task { @MainActor in
                if let skipEvent = event as? MPSkipIntervalCommandEvent {
                    await PlaybackManager.shared.skipBackward(by: skipEvent.interval)
                } else {
                    await PlaybackManager.shared.skipBackward(by: 15)
                }
            }
            return .success
        }
        
        // Seek command
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            Task { @MainActor in
                if let seekEvent = event as? MPChangePlaybackPositionCommandEvent {
                    await PlaybackManager.shared.seek(to: seekEvent.positionTime)
                }
            }
            return .success
        }
        
        // Playback rate
        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            if let rateEvent = event as? MPChangePlaybackRateCommandEvent {
                PlaybackManager.shared.setPlaybackRate(rateEvent.playbackRate)
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - Update Now Playing Info
    
    /// Update the Now Playing info on lock screen
    func updateNowPlaying(
        episode: EpisodeRecord,
        podcast: PodcastRecord,
        currentTime: TimeInterval,
        duration: TimeInterval,
        playbackRate: Float,
        isPlaying: Bool
    ) {
        var info: [String: Any] = [:]
        
        // Title and artist
        info[MPMediaItemPropertyTitle] = episode.title
        info[MPMediaItemPropertyArtist] = podcast.title
        info[MPMediaItemPropertyAlbumTitle] = podcast.title
        
        // Times
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        
        // Media type
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        info[MPNowPlayingInfoPropertyIsLiveStream] = false
        
        // Artwork - load asynchronously
        if let artworkURLString = episode.imageURL ?? podcast.artworkURL,
           let artworkURL = URL(string: artworkURLString) {
            Task {
                if let image = await loadArtwork(from: artworkURL) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    var updatedInfo = info
                    updatedInfo[MPMediaItemPropertyArtwork] = artwork
                    await MainActor.run {
                        nowPlayingInfo.nowPlayingInfo = updatedInfo
                    }
                }
            }
        }
        
        nowPlayingInfo.nowPlayingInfo = info
    }
    
    /// Update just the playback state (time, rate, playing status)
    func updatePlaybackState(
        currentTime: TimeInterval,
        duration: TimeInterval,
        playbackRate: Float,
        isPlaying: Bool
    ) {
        guard var info = nowPlayingInfo.nowPlayingInfo else { return }
        
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        
        nowPlayingInfo.nowPlayingInfo = info
    }
    
    /// Clear Now Playing info
    func clearNowPlaying() {
        nowPlayingInfo.nowPlayingInfo = nil
    }
    
    // MARK: - Artwork Loading
    
    private func loadArtwork(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
