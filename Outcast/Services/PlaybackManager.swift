//
//  PlaybackManager.swift
//  Outcast
//
//  Main playback coordinator for podcast episodes
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import GRDB

/// Coordinates playback, database updates, and UI state
@MainActor
class PlaybackManager: ObservableObject {
    
    static let shared = PlaybackManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var currentEpisode: EpisodeRecord?
    @Published private(set) var currentPodcast: PodcastRecord?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var playbackRate: Float = 1.0
    @Published private(set) var isBuffering = false
    
    // MARK: - Private Properties
    
    private let player = AudioPlayer()
    private let database = AppDatabase.shared
    private let fileStorage = FileStorageManager.shared
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupPlayerObservers()
        setupNotifications()
    }
    
    // MARK: - Setup
    
    private func setupPlayerObservers() {
        player.$isPlaying
            .assign(to: &$isPlaying)
        
        player.$currentTime
            .assign(to: &$currentTime)
        
        player.$duration
            .assign(to: &$duration)
        
        player.$playbackRate
            .assign(to: &$playbackRate)
        
        player.$isBuffering
            .assign(to: &$isBuffering)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackEnd),
            name: .audioPlayerDidFinishPlaying,
            object: nil
        )
    }
    
    // MARK: - Load Episode
    
    /// Load and optionally play an episode
    func load(episode: EpisodeRecord, autoPlay: Bool = false) async throws {
        // Save current episode position if playing
        if let currentEpisode = currentEpisode, currentEpisode.uuid != episode.uuid {
            try await savePlaybackPosition()
        }
        
        // Fetch podcast info
        let podcast = try await database.readAsync { db in
            try PodcastRecord.fetchOne(db, key: episode.podcastId)
        }
        
        currentEpisode = episode
        currentPodcast = podcast
        
        // Determine playback URL
        let playbackURL: URL
        if episode.downloadStatus == .downloaded,
           let localPath = episode.localFilePath {
            // Play from local file
            let fileExtension = await fileStorage.fileExtension(from: episode.audioMimeType, or: episode.audioURL)
            playbackURL = await fileStorage.fileURL(for: episode.uuid, fileExtension: fileExtension)
        } else {
            // Stream from URL
            guard let url = URL(string: episode.audioURL) else {
                throw PlaybackError.invalidURL
            }
            playbackURL = url
        }
        
        // Load into player
        player.load(url: playbackURL, startTime: episode.playedUpTo)
        
        // Start update timer
        startUpdateTimer()
        
        if autoPlay {
            try await play()
        }
    }
    
    // MARK: - Playback Control
    
    /// Start or resume playback
    func play() async throws {
        guard currentEpisode != nil else {
            throw PlaybackError.noEpisodeLoaded
        }
        
        player.play()
        
        // Update playing status in database if needed
        if let episode = currentEpisode, episode.playingStatus == .notPlayed {
            try await database.writeAsync { db in
                var updatedEpisode = episode
                updatedEpisode.playingStatus = .inProgress
                try updatedEpisode.update(db)
            }
            // Refresh current episode
            await refreshCurrentEpisode()
        }
    }
    
    /// Pause playback
    func pause() {
        player.pause()
        Task {
            try? await savePlaybackPosition()
        }
    }
    
    /// Toggle play/pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            Task {
                try? await play()
            }
        }
    }
    
    /// Seek to a specific time
    func seek(to time: TimeInterval) async {
        player.seek(to: time)
        try? await savePlaybackPosition()
    }
    
    /// Skip forward
    func skipForward(by seconds: TimeInterval = 15) async {
        player.skipForward(by: seconds)
        try? await savePlaybackPosition()
    }
    
    /// Skip backward
    func skipBackward(by seconds: TimeInterval = 15) async {
        player.skipBackward(by: seconds)
        try? await savePlaybackPosition()
    }
    
    /// Set playback speed
    func setPlaybackRate(_ rate: Float) {
        player.setPlaybackRate(rate)
    }
    
    // MARK: - Update Timer
    
    private func startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                try? await self?.savePlaybackPosition()
            }
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - Database Operations
    
    /// Save current playback position to database
    private func savePlaybackPosition() async throws {
        guard let episode = currentEpisode else { return }
        
        try await database.writeAsync { db in
            var updatedEpisode = episode
            updatedEpisode.playedUpTo = self.currentTime
            try updatedEpisode.update(db)
        }
        
        await refreshCurrentEpisode()
    }
    
    /// Refresh the current episode from database
    private func refreshCurrentEpisode() async {
        guard let uuid = currentEpisode?.uuid else { return }
        
        currentEpisode = try? await database.readAsync { db in
            try EpisodeRecord.filter(Column("uuid") == uuid).fetchOne(db)
        }
    }
    
    /// Mark current episode as completed
    private func markAsCompleted() async throws {
        guard let episode = currentEpisode else { return }
        
        try await database.writeAsync { db in
            var updatedEpisode = episode
            updatedEpisode.playingStatus = .completed
            updatedEpisode.playedUpTo = updatedEpisode.duration ?? 0
            try updatedEpisode.update(db)
        }
        
        await refreshCurrentEpisode()
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handlePlaybackEnd() {
        Task {
            try? await markAsCompleted()
            stopUpdateTimer()
            
            // Clear current episode
            currentEpisode = nil
            currentPodcast = nil
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        updateTimer?.invalidate()
    }
    
    // MARK: - Accessors
    
    /// Get internal AVPlayer for video playback
    func getAVPlayer() -> AVPlayer? {
        return player.getAVPlayer()
    }
    
    /// Check if an episode is currently playing
    func isCurrentlyPlaying(episodeUUID: String) -> Bool {
        return currentEpisode?.uuid == episodeUUID && isPlaying
    }
    
    /// Get remaining time for current episode
    var remainingTime: TimeInterval {
        guard duration > 0 else { return 0 }
        return max(0, duration - currentTime)
    }
    
    /// Get progress percentage (0-1)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, currentTime / duration)
    }
}

// MARK: - Error Types

enum PlaybackError: LocalizedError {
    case noEpisodeLoaded
    case invalidURL
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .noEpisodeLoaded:
            return "No episode loaded for playback"
        case .invalidURL:
            return "Invalid episode URL"
        case .fileNotFound:
            return "Episode file not found"
        }
    }
}
