//
//  NowPlayingManager.swift
//  Outcast
//
//  Manages Now Playing info and remote command handling
//

import MediaPlayer
import UIKit
import Foundation

// #region agent log
private func debugLog(location: String, message: String, data: [String: Any], hypothesisId: String) {
    let logPath = "/Users/erandrorsmacbookpro/Outcast-AI/Outcast/.cursor/debug.log"
    let logEntry: [String: Any] = [
        "timestamp": Date().timeIntervalSince1970 * 1000,
        "location": location,
        "message": message,
        "data": data,
        "sessionId": "debug-session",
        "hypothesisId": hypothesisId
    ]
    if let jsonData = try? JSONSerialization.data(withJSONObject: logEntry),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        if let fileHandle = FileHandle(forWritingAtPath: logPath) {
            fileHandle.seekToEndOfFile()
            fileHandle.write((jsonString + "\n").data(using: .utf8)!)
            fileHandle.closeFile()
        } else {
            try? (jsonString + "\n").write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }
}
// #endregion

/// Manages lock screen Now Playing info and remote controls
@MainActor
class NowPlayingManager {
    
    static let shared = NowPlayingManager()
    
    private let commandCenter = MPRemoteCommandCenter.shared()
    private let nowPlayingInfo = MPNowPlayingInfoCenter.default()
    
    private init() {
        // #region agent log
        debugLog(location: "NowPlayingManager.swift:20", message: "NowPlayingManager init called", data: [:], hypothesisId: "A")
        // #endregion
        
        // Configure audio session BEFORE setting up remote commands
        // This ensures iOS knows we're a playback app when commands are registered
        configureAudioSession()
        
        setupRemoteCommands()
        // #region agent log
        debugLog(location: "NowPlayingManager.swift:24", message: "setupRemoteCommands completed", data: [:], hypothesisId: "A")
        // #endregion
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // #region agent log
            debugLog(location: "NowPlayingManager.swift:40", message: "Configuring audio session in NowPlayingManager", data: [
                "beforeCategory": audioSession.category.rawValue
            ], hypothesisId: "G")
            // #endregion
            
            try audioSession.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
            try audioSession.setActive(true)
            
            // #region agent log
            debugLog(location: "NowPlayingManager.swift:50", message: "Audio session configured successfully", data: [
                "category": audioSession.category.rawValue,
                "mode": audioSession.mode.rawValue
            ], hypothesisId: "G")
            // #endregion
        } catch {
            // #region agent log
            debugLog(location: "NowPlayingManager.swift:58", message: "Failed to configure audio session", data: [
                "error": error.localizedDescription
            ], hypothesisId: "G")
            // #endregion
            print("Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - Setup Remote Commands
    
    private func setupRemoteCommands() {
        // #region agent log
        let audioSession = AVAudioSession.sharedInstance()
        debugLog(location: "NowPlayingManager.swift:30", message: "setupRemoteCommands started", data: [
            "audioSessionActive": audioSession.category == .playback,
            "category": audioSession.category.rawValue
        ], hypothesisId: "F")
        // #endregion
        
        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            // #region agent log
            debugLog(location: "NowPlayingManager.swift:37", message: "Play command received", data: [:], hypothesisId: "D")
            // #endregion
            Task { @MainActor in
                try? await PlaybackManager.shared.play()
            }
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            // #region agent log
            debugLog(location: "NowPlayingManager.swift:48", message: "Pause command received", data: [:], hypothesisId: "D")
            // #endregion
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
        // #region agent log
        debugLog(location: "NowPlayingManager.swift:112", message: "updateNowPlaying called", data: [
            "episodeTitle": episode.title,
            "podcastTitle": podcast.title,
            "currentTime": currentTime,
            "duration": duration,
            "playbackRate": playbackRate,
            "isPlaying": isPlaying
        ], hypothesisId: "B")
        // #endregion
        
        // iOS requires valid duration to show Now Playing controls
        // Don't set Now Playing info if duration isn't available yet
        guard duration > 0 else {
            // #region agent log
            debugLog(location: "NowPlayingManager.swift:133", message: "Skipping Now Playing update - invalid duration", data: [
                "duration": duration
            ], hypothesisId: "H")
            // #endregion
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
        
        // #region agent log
        let audioSession = AVAudioSession.sharedInstance()
        let durationValue = info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval ?? 0
        let elapsedValue = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval ?? 0
        let rateValue = info[MPNowPlayingInfoPropertyPlaybackRate] as? Float ?? 0
        debugLog(location: "NowPlayingManager.swift:169", message: "Setting nowPlayingInfo", data: [
            "infoCount": info.count,
            "hasTitle": info[MPMediaItemPropertyTitle] != nil,
            "hasArtist": info[MPMediaItemPropertyArtist] != nil,
            "hasDuration": info[MPMediaItemPropertyPlaybackDuration] != nil,
            "duration": durationValue,
            "elapsed": elapsedValue,
            "rate": rateValue,
            "isOtherAudioPlaying": audioSession.isOtherAudioPlaying,
            "audioSessionCategory": audioSession.category.rawValue
        ], hypothesisId: "H")
        // #endregion
        
        nowPlayingInfo.nowPlayingInfo = info
        
        // #region agent log
        let retrievedInfo = nowPlayingInfo.nowPlayingInfo
        debugLog(location: "NowPlayingManager.swift:185", message: "nowPlayingInfo set complete", data: [
            "playCommandEnabled": commandCenter.playCommand.isEnabled,
            "pauseCommandEnabled": commandCenter.pauseCommand.isEnabled,
            "toggleCommandEnabled": commandCenter.togglePlayPauseCommand.isEnabled,
            "infoWasSet": retrievedInfo != nil,
            "retrievedInfoCount": retrievedInfo?.count ?? 0
        ], hypothesisId: "H")
        // #endregion
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
