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

/// Download status for an episode
enum DownloadStatus: Int, Codable, Sendable {
    case notDownloaded = 0
    case queued = 1
    case downloading = 2
    case downloaded = 3
    case failed = 4
    case paused = 5
}

/// Auto-download status tracking
enum AutoDownloadStatus: Int, Codable, Sendable {
    case notSpecified = 0
    case autoDownloaded = 1
    case userDownloaded = 2
    case playerStreaming = 3
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
    
    // Extended metadata fields
    var link: String?               // Episode webpage URL
    var explicit: Bool?
    var subtitle: String?
    var author: String?             // Episode-specific author/guest
    var contentHTML: String?        // Rich show notes (content:encoded)
    var chaptersURL: String?        // podcast:chapters URL
    var transcripts: String?        // JSON: [{"url": "...", "type": "text/vtt", "language": "en"}]
    
    // Playback state
    var playedUpTo: TimeInterval
    var playingStatus: PlayingStatus
    var lastPlayedAt: Date?
    var isDownloaded: Bool
    var downloadedPath: String?
    
    // Download management
    var downloadStatus: DownloadStatus
    var downloadProgress: Double
    var localFilePath: String?
    var downloadedFileSize: Int64?
    var downloadTaskIdentifier: String?
    var downloadError: String?
    var autoDownloadStatus: AutoDownloadStatus
    
    // AI tagging
    var needsTagging: Bool
    
    // Saved episodes
    var isSaved: Bool
    var savedAt: Date?
    
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
        link: String? = nil,
        explicit: Bool? = nil,
        subtitle: String? = nil,
        author: String? = nil,
        contentHTML: String? = nil,
        chaptersURL: String? = nil,
        transcripts: String? = nil,
        playedUpTo: TimeInterval = 0,
        playingStatus: PlayingStatus = .notPlayed,
        lastPlayedAt: Date? = nil,
        isDownloaded: Bool = false,
        downloadedPath: String? = nil,
        downloadStatus: DownloadStatus = .notDownloaded,
        downloadProgress: Double = 0.0,
        localFilePath: String? = nil,
        downloadedFileSize: Int64? = nil,
        downloadTaskIdentifier: String? = nil,
        downloadError: String? = nil,
        autoDownloadStatus: AutoDownloadStatus = .notSpecified,
        needsTagging: Bool = true,
        isSaved: Bool = false,
        savedAt: Date? = nil
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
        self.link = link
        self.explicit = explicit
        self.subtitle = subtitle
        self.author = author
        self.contentHTML = contentHTML
        self.chaptersURL = chaptersURL
        self.transcripts = transcripts
        self.playedUpTo = playedUpTo
        self.playingStatus = playingStatus
        self.lastPlayedAt = lastPlayedAt
        self.isDownloaded = isDownloaded
        self.downloadedPath = downloadedPath
        self.downloadStatus = downloadStatus
        self.downloadProgress = downloadProgress
        self.localFilePath = localFilePath
        self.downloadedFileSize = downloadedFileSize
        self.downloadTaskIdentifier = downloadTaskIdentifier
        self.downloadError = downloadError
        self.autoDownloadStatus = autoDownloadStatus
        self.needsTagging = needsTagging
        self.isSaved = isSaved
        self.savedAt = savedAt
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
    
    /// Fetch history - episodes that have been played, ordered by most recent play
    static func fetchHistory(limit: Int = 50, db: Database) throws -> [EpisodeRecord] {
        try EpisodeRecord
            .filter(Column("lastPlayedAt") != nil)
            .filter(Column("playedUpTo") >= 180)  // Minimum 3 minutes listened
            .order(Column("lastPlayedAt").desc)
            .limit(limit)
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
    
    /// Fetch downloaded episodes
    static func fetchDownloaded(db: Database) throws -> [EpisodeRecord] {
        try EpisodeRecord
            .filter(Column("downloadStatus") == DownloadStatus.downloaded.rawValue)
            .order(Column("publishedDate").desc)
            .fetchAll(db)
    }
    
    /// Fetch episodes currently downloading
    static func fetchDownloading(db: Database) throws -> [EpisodeRecord] {
        try EpisodeRecord
            .filter(Column("downloadStatus") == DownloadStatus.downloading.rawValue || 
                   Column("downloadStatus") == DownloadStatus.queued.rawValue)
            .order(Column("publishedDate").desc)
            .fetchAll(db)
    }
    
    /// Update download status
    mutating func updateDownloadStatus(_ status: DownloadStatus, db: Database) throws {
        downloadStatus = status
        if status == .downloaded {
            isDownloaded = true
        } else if status == .notDownloaded || status == .failed {
            isDownloaded = false
        }
        try update(db)
    }
    
    /// Update download progress
    mutating func updateDownloadProgress(_ progress: Double, db: Database) throws {
        downloadProgress = progress
        try update(db)
    }
    
    /// Fetch episodes that need AI tagging
    static func fetchNeedingTagging(limit: Int, db: Database) throws -> [EpisodeRecord] {
        try EpisodeRecord
            .filter(Column("needsTagging") == true)
            .order(Column("publishedDate").desc)
            .limit(limit)
            .fetchAll(db)
    }
    
    /// Mark episode as tagged (no longer needs tagging)
    mutating func markTaggingComplete(db: Database) throws {
        needsTagging = false
        try update(db)
    }
    
    /// Toggle saved state
    mutating func toggleSaved(db: Database) throws {
        isSaved.toggle()
        savedAt = isSaved ? Date() : nil
        try update(db)
    }
    
    /// Fetch saved episodes, ordered by saved date (most recent first)
    static func fetchSaved(limit: Int = 50, offset: Int = 0, db: Database) throws -> [EpisodeRecord] {
        try EpisodeRecord
            .filter(Column("isSaved") == true)
            .order(Column("savedAt").desc)
            .limit(limit, offset: offset)
            .fetchAll(db)
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
