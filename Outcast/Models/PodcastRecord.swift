//
//  PodcastRecord.swift
//  Outcast
//
//  GRDB record for Podcast storage
//

import Foundation
import GRDB

/// Represents a podcast subscription in the database
struct PodcastRecord: Identifiable, Codable, Sendable {
    var id: Int64?
    var uuid: String
    var feedURL: String
    var title: String
    var author: String?
    var podcastDescription: String?
    var artworkURL: String?
    var homePageURL: String?
    var lastRefreshDate: Date?
    var contentHash: String?
    var etag: String?
    var lastModified: String?
    var addedDate: Date
    var artworkColor: String?
    var isFullyLoaded: Bool
    var isUpNext: Bool
    
    // Extended metadata fields
    var language: String?
    var showType: String?           // "episodic" | "serial"
    var copyright: String?
    var ownerName: String?
    var ownerEmail: String?
    var explicit: Bool?
    var subtitle: String?
    var fundingURL: String?
    var htmlDescription: String?    // Rich HTML version
    var categories: String?         // JSON array: ["Business", "Technology"]
    
    init(
        id: Int64? = nil,
        uuid: String = UUID().uuidString,
        feedURL: String,
        title: String,
        author: String? = nil,
        podcastDescription: String? = nil,
        artworkURL: String? = nil,
        homePageURL: String? = nil,
        lastRefreshDate: Date? = nil,
        contentHash: String? = nil,
        etag: String? = nil,
        lastModified: String? = nil,
        addedDate: Date = Date(),
        artworkColor: String? = nil,
        isFullyLoaded: Bool = true,
        isUpNext: Bool = false,
        language: String? = nil,
        showType: String? = nil,
        copyright: String? = nil,
        ownerName: String? = nil,
        ownerEmail: String? = nil,
        explicit: Bool? = nil,
        subtitle: String? = nil,
        fundingURL: String? = nil,
        htmlDescription: String? = nil,
        categories: String? = nil
    ) {
        self.id = id
        self.uuid = uuid
        self.feedURL = feedURL
        self.title = title
        self.author = author
        self.podcastDescription = podcastDescription
        self.artworkURL = artworkURL
        self.homePageURL = homePageURL
        self.lastRefreshDate = lastRefreshDate
        self.contentHash = contentHash
        self.etag = etag
        self.lastModified = lastModified
        self.addedDate = addedDate
        self.artworkColor = artworkColor
        self.isFullyLoaded = isFullyLoaded
        self.isUpNext = isUpNext
        self.language = language
        self.showType = showType
        self.copyright = copyright
        self.ownerName = ownerName
        self.ownerEmail = ownerEmail
        self.explicit = explicit
        self.subtitle = subtitle
        self.fundingURL = fundingURL
        self.htmlDescription = htmlDescription
        self.categories = categories
    }
}

// MARK: - GRDB Protocols

extension PodcastRecord: FetchableRecord, MutablePersistableRecord {
    nonisolated static let databaseTableName = "podcast"
    
    /// Update auto-generated id after insertion
    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    /// The episodes association
    nonisolated static let episodes = hasMany(EpisodeRecord.self)
    
    /// Fetch the associated episodes
    nonisolated var episodes: QueryInterfaceRequest<EpisodeRecord> {
        request(for: PodcastRecord.episodes)
    }
}

// MARK: - Database Operations

extension PodcastRecord {
    
    /// Fetch all podcasts ordered by title
    static func fetchAllOrderedByTitle(db: Database) throws -> [PodcastRecord] {
        try PodcastRecord
            .order(Column("title").collating(.localizedCaseInsensitiveCompare))
            .fetchAll(db)
    }
    
    /// Fetch a podcast by its feed URL
    static func fetchByFeedURL(_ feedURL: String, db: Database) throws -> PodcastRecord? {
        try PodcastRecord
            .filter(Column("feedURL") == feedURL)
            .fetchOne(db)
    }
    
    /// Fetch a podcast by its UUID
    static func fetchByUUID(_ uuid: String, db: Database) throws -> PodcastRecord? {
        try PodcastRecord
            .filter(Column("uuid") == uuid)
            .fetchOne(db)
    }
    
    /// Check if a podcast with the given feed URL exists
    static func exists(feedURL: String, db: Database) throws -> Bool {
        try PodcastRecord
            .filter(Column("feedURL") == feedURL)
            .fetchCount(db) > 0
    }
    
    /// Delete a podcast and all its episodes (cascade)
    func deleteWithEpisodes(db: Database) throws {
        try delete(db)
    }
}
