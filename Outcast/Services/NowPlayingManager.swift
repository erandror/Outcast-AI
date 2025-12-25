//
//  NowPlayingManager.swift
//  Outcast
//
//  Manages Now Playing info and remote command handling
//

import MediaPlayer
import UIKit
import Foundation

/// Manages lock screen Now Playing info and remote controls
@MainActor
class NowPlayingManager {
    
    static let shared = NowPlayingManager()
    
    private let commandCenter = MPRemoteCommandCenter.shared()
    private let nowPlayingInfo = MPNowPlayingInfoCenter.default()
    
    // Artwork cache to prevent re-downloading on every update
    private var cachedArtwork: MPMediaItemArtwork?
    private var cachedArtworkURL: String?
    
    private init() {
        // Configure audio session BEFORE setting up remote commands
        // This ensures iOS knows we're a playback app when commands are registered
        configureAudioSession()
        
        setupRemoteCommands()
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - Setup Remote Commands
    
    private func setupRemoteCommands() {
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            Task { @MainActor in
                try? await PlaybackManager.shared.play()
            }
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            PlaybackManager.shared.pause()
            return .success
        }
        
        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            PlaybackManager.shared.togglePlayPause()
            return .success
        }
        
        // Skip forward
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipForwardCommand.addTarget { event in
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
        commandCenter.skipBackwardCommand.addTarget { event in
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
        commandCenter.changePlaybackPositionCommand.addTarget { event in
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
        commandCenter.changePlaybackRateCommand.addTarget { event in
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
        // iOS requires valid duration to show Now Playing controls
        // Don't set Now Playing info if duration isn't available yet
        guard duration > 0 else {
            return
        }
        
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
        
        // Artwork - use cache if available, otherwise load asynchronously
        let artworkURLString = episode.imageURL ?? podcast.artworkURL
        
        // Check if we have cached artwork for this URL
        if let artworkURLString = artworkURLString, artworkURLString == cachedArtworkURL, let cachedArtwork = cachedArtwork {
            // Use cached artwork - set info immediately with artwork
            info[MPMediaItemPropertyArtwork] = cachedArtwork
            nowPlayingInfo.nowPlayingInfo = info
        } else if let artworkURLString = artworkURLString, let artworkURL = URL(string: artworkURLString) {
            // Need to load artwork - set info with cached artwork if available (even if wrong URL),
            // then update once new artwork loads
            if let cachedArtwork = cachedArtwork {
                info[MPMediaItemPropertyArtwork] = cachedArtwork
            }
            nowPlayingInfo.nowPlayingInfo = info
            
            // Load new artwork asynchronously
            Task {
                if let image = await loadArtwork(from: artworkURL) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    // Cache the artwork
                    self.cachedArtwork = artwork
                    self.cachedArtworkURL = artworkURLString
                    
                    // Update info with new artwork
                    var updatedInfo = info
                    updatedInfo[MPMediaItemPropertyArtwork] = artwork
                    self.nowPlayingInfo.nowPlayingInfo = updatedInfo
                }
            }
        } else {
            // No artwork URL - set info without artwork
            nowPlayingInfo.nowPlayingInfo = info
        }
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
        // Clear cached artwork when clearing now playing
        cachedArtwork = nil
        cachedArtworkURL = nil
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
