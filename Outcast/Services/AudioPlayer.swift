//
//  AudioPlayer.swift
//  Outcast
//
//  AVPlayer wrapper for podcast audio playback
//

import AVFoundation
import MediaPlayer
import Combine
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

/// Wraps AVPlayer for audio playback with session management
@MainActor
class AudioPlayer: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isBuffering = false
    @Published private(set) var playbackRate: Float = 1.0
    
    // MARK: - Event Callbacks
    
    /// Called when audio interruption begins (phone call, Siri, etc.)
    var onInterruptionBegan: (() -> Void)?
    
    /// Called when route change requires pause (headphones disconnected)
    var onRouteChangeRequiresPause: (() -> Void)?
    
    /// Track if we were playing before interruption to resume properly
    private(set) var wasPlayingBeforeInterruption: Bool = false
    
    // MARK: - Private Properties
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupAudioSession()
        setupNotifications()
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.pause()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // #region agent log
            debugLog(location: "AudioPlayer.swift:49", message: "Setting audio session category", data: [:], hypothesisId: "C")
            // #endregion
            
            try audioSession.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
            try audioSession.setActive(true)
            
            // #region agent log
            debugLog(location: "AudioPlayer.swift:56", message: "Audio session configured", data: [
                "category": audioSession.category.rawValue,
                "mode": audioSession.mode.rawValue,
                "isActive": true
            ], hypothesisId: "C")
            // #endregion
        } catch {
            // #region agent log
            debugLog(location: "AudioPlayer.swift:64", message: "Audio session setup failed", data: ["error": error.localizedDescription], hypothesisId: "C")
            // #endregion
            print("Failed to set up audio session: \(error)")
        }
    }
    
    // MARK: - Notifications Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Load Episode
    
    /// Load an episode for playback
    func load(url: URL, startTime: TimeInterval = 0) {
        cleanup()
        
        let asset = AVURLAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        setupPlayerObservers()
        
        if startTime > 0 {
            seek(to: startTime)
        }
    }
    
    // MARK: - Playback Control
    
    /// Start or resume playback
    func play() {
        guard let player = player else {
            // #region agent log
            debugLog(location: "AudioPlayer.swift:115", message: "play() called but player is nil", data: [:], hypothesisId: "H")
            // #endregion
            return
        }
        
        // #region agent log
        let audioSession = AVAudioSession.sharedInstance()
        debugLog(location: "AudioPlayer.swift:118", message: "play() called - checking session", data: [
            "isOtherAudioPlaying": audioSession.isOtherAudioPlaying,
            "category": audioSession.category.rawValue,
            "mode": audioSession.mode.rawValue,
            "playerRate": player.rate,
            "playerTimeControlStatus": player.timeControlStatus.rawValue
        ], hypothesisId: "H")
        // #endregion
        
        // Ensure audio session is active before playing
        do {
            try audioSession.setActive(true)
            // #region agent log
            debugLog(location: "AudioPlayer.swift:132", message: "Audio session reactivated successfully", data: [:], hypothesisId: "F")
            // #endregion
        } catch {
            // #region agent log
            debugLog(location: "AudioPlayer.swift:137", message: "Failed to reactivate audio session", data: ["error": error.localizedDescription], hypothesisId: "H")
            // #endregion
        }
        
        player.rate = playbackRate
        isPlaying = true
        
        // #region agent log
        debugLog(location: "AudioPlayer.swift:147", message: "play() completed", data: [
            "newRate": player.rate,
            "isPlaying": isPlaying,
            "timeControlStatus": player.timeControlStatus.rawValue
        ], hypothesisId: "H")
        // #endregion
    }
    
    /// Pause playback
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    /// Toggle play/pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    /// Seek to a specific time
    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }
    
    /// Skip forward by a duration
    func skipForward(by seconds: TimeInterval) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    /// Skip backward by a duration
    func skipBackward(by seconds: TimeInterval) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    /// Set playback rate (speed)
    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }
    
    // MARK: - Player Observers
    
    private func setupPlayerObservers() {
        guard let player = player, let playerItem = playerItem else { return }
        
        // Observe time
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.currentTime = time.seconds
            }
        }
        
        // Observe duration
        playerItem.publisher(for: \.duration)
            .sink { [weak self] duration in
                if duration.isNumeric {
                    self?.duration = duration.seconds
                }
            }
            .store(in: &cancellables)
        
        // Observe status
        playerItem.publisher(for: \.status)
            .sink { status in
                if status == .failed {
                    print("Player item failed: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                }
            }
            .store(in: &cancellables)
        
        // Observe buffering
        playerItem.publisher(for: \.isPlaybackBufferEmpty)
            .sink { [weak self] isEmpty in
                self?.isBuffering = isEmpty
            }
            .store(in: &cancellables)
        
        // Observe playback end
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                self?.handlePlaybackEnd()
            }
            .store(in: &cancellables)
        
        // Observe rate changes
        player.publisher(for: \.rate)
            .sink { [weak self] rate in
                self?.isPlaying = rate > 0
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Track whether we were playing before interruption so we can resume if needed
            wasPlayingBeforeInterruption = isPlaying
            // Notify PlaybackManager to handle pause with position save
            onInterruptionBegan?()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) && wasPlayingBeforeInterruption {
                play()
                wasPlayingBeforeInterruption = false
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Notify PlaybackManager to handle pause with position save
            onRouteChangeRequiresPause?()
        default:
            break
        }
    }
    
    private func handlePlaybackEnd() {
        isPlaying = false
        // Notify PlaybackManager that episode finished
        NotificationCenter.default.post(name: .audioPlayerDidFinishPlaying, object: nil)
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        cancellables.removeAll()
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }
    
    // MARK: - Accessors
    
    /// Get the internal AVPlayer for video playback
    func getAVPlayer() -> AVPlayer? {
        return player
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let audioPlayerDidFinishPlaying = Notification.Name("audioPlayerDidFinishPlaying")
}
