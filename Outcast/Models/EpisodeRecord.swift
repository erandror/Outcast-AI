//
//  EpisodeRecord.swift
//  Outcast
//
//  GRDB record for Episode storage
//

import Foundation
import GRDB

/// Playing status for an episode
enum PlayingStatus: Int, Codable, Sendable {
    case notPlayed = 0
    case inProgress = 1
    case completed = 2
}

/// Represents a podcast episode in the database
struct EpisodeRecord: Identifiable, Codable, Sendable {
    var id: Int64?
    var uuid: String
    var podcastId: Int64
    var guid: String
    var title: String
    var episodeDescription: String?
    var audioURL: String
    var audioMimeType: String?
    var fileSize: Int64?
    var duration: TimeInterval?
    var publishedDate: Date?
    var imageURL: String?
    var episodeNumber: Int?
    var seasonNumber: Int?
    var episodeType: String?
    
    // Playback state
    var playedUpTo: TimeInterval
    var playingStatus: PlayingStatus
    var isDownloaded: Bool
    var downloadedPath: String?
    
    init(
        id: Int64? = nil,
        uuid: String = UUID().uuidString,
        podcastId: Int64,
        guid: String,
        title: String,
        episodeDescription: String? = nil,
        audioURL: String,
        audioMimeType: String? = nil,
        fileSize: Int64? = nil,
        duration: TimeInterval? = nil,
        publishedDate: Date? = nil,
        imageURL: String? = nil,
        episodeNumber: Int? = nil,
        seasonNumber: Int? = nil,
        episodeType: String? = nil,
        playedUpTo: TimeInterval = 0,
        playingStatus: PlayingStatus = .notPlayed,
        isDownloaded: Bool = false,
        downloadedPath: String? = nil
    ) {
        self.id = id
        self.uuid = uuid
        self.podcastId = podcastId
        self.guid = guid
        self.title = title
        self.episodeDescription = episodeDescription
        self.audioURL = audioURL
        self.audioMimeType = audioMimeType
        self.fileSize = fileSize
        self.duration = duration
        self.publishedDate = publishedDate
        self.imageURL = imageURL
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.episodeType = episodeType
        self.playedUpTo = playedUpTo
        self.playingStatus = playingStatus
        self.isDownloaded = isDownloaded
        self.downloadedPath = downloadedPath
    }
}

// MARK: - GRDB Protocols

extension EpisodeRecord: FetchableRecord, MutablePersistableRecord {
    nonisolated static let databaseTableName = "episode"
    
    /// Update auto-generated id after insertion
    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    /// The parent podcast association
    nonisolated static let podcast = belongsTo(PodcastRecord.self)
    
    /// Fetch the associated podcast
    nonisolated var podcast: QueryInterfaceRequest<PodcastRecord> {
        request(for: EpisodeRecord.podcast)
    }
}

// MARK: - Database Operations

extension EpisodeRecord {
    
    /// Fetch all episodes for a podcast, ordered by published date (newest first)
    static func fetchAllForPodcast(_ podcastId: Int64, db: Database) throws -> [EpisodeRecord] {
        try EpisodeRecord
            .filter(Column("podcastId") == podcastId)
            .order(Column("publishedDate").desc)
            .fetchAll(db)
    }
    
    /// Fetch the latest episodes across all podcasts
    static func fetchLatest(limit: Int = 50, db: Database) throws -> [EpisodeRecord] {
        try EpisodeRecord
            .order(Column("publishedDate").desc)
            .limit(limit)
            .fetchAll(db)
    }
    
    /// Fetch unplayed episodes, ordered by published date (newest first)
    static func fetchUnplayed(limit: Int = 50, db: Database) throws -> [EpisodeRecord] {
        try EpisodeRecord
            .filter(Column("playingStatus") == PlayingStatus.notPlayed.rawValue)
            .order(Column("publishedDate").desc)
            .limit(limit)
            .fetchAll(db)
    }
    
    /// Fetch in-progress episodes
    static func fetchInProgress(db: Database) throws -> [EpisodeRecord] {
        try EpisodeRecord
            .filter(Column("playingStatus") == PlayingStatus.inProgress.rawValue)
            .order(Column("publishedDate").desc)
            .fetchAll(db)
    }
    
    /// Check if an episode with the given guid exists for a podcast
    static func exists(guid: String, podcastId: Int64, db: Database) throws -> Bool {
        try EpisodeRecord
            .filter(Column("guid") == guid && Column("podcastId") == podcastId)
            .fetchCount(db) > 0
    }
    
    /// Fetch an episode by guid and podcast ID
    static func fetchByGuid(_ guid: String, podcastId: Int64, db: Database) throws -> EpisodeRecord? {
        try EpisodeRecord
            .filter(Column("guid") == guid && Column("podcastId") == podcastId)
            .fetchOne(db)
    }
    
    /// Update playback position
    mutating func updatePlaybackPosition(_ position: TimeInterval, db: Database) throws {
        playedUpTo = position
        if playingStatus == .notPlayed {
            playingStatus = .inProgress
        }
        try update(db)
    }
    
    /// Mark as completed
    mutating func markAsCompleted(db: Database) throws {
        playingStatus = .completed
        try update(db)
    }
}

// MARK: - Computed Properties

extension EpisodeRecord {
    
    /// Format duration as readable string
    var durationFormatted: String {
        guard let duration = duration else { return "" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Remaining time based on playback position
    var remainingTime: TimeInterval? {
        guard let duration = duration else { return nil }
        return max(0, duration - playedUpTo)
    }
    
    /// Remaining time formatted
    var remainingTimeFormatted: String? {
        guard let remaining = remainingTime else { return nil }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(minutes)m left"
        }
    }
}
