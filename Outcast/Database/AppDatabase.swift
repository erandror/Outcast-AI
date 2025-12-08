//
//  AppDatabase.swift
//  Outcast
//
//  Database manager using GRDB for cross-platform SQLite storage
//

import Foundation
import GRDB

/// The main database manager for Outcast
/// Provides thread-safe access to the SQLite database
final class AppDatabase: Sendable {
    
    /// Shared instance for the app
    nonisolated static let shared = AppDatabase()
    
    /// The database queue for thread-safe access
    let dbQueue: DatabaseQueue
    
    nonisolated private init() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directoryURL = appSupportURL.appendingPathComponent("Outcast", isDirectory: true)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            
            let databaseURL = directoryURL.appendingPathComponent("outcast.sqlite")
            dbQueue = try DatabaseQueue(path: databaseURL.path)
            
            try migrator.migrate(dbQueue)
        } catch {
            fatalError("Database initialization failed: \(error)")
        }
    }
    
    /// For testing/preview with in-memory database
    nonisolated init(inMemory: Bool) throws {
        if inMemory {
            dbQueue = try DatabaseQueue()
        } else {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directoryURL = appSupportURL.appendingPathComponent("Outcast", isDirectory: true)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            
            let databaseURL = directoryURL.appendingPathComponent("outcast.sqlite")
            dbQueue = try DatabaseQueue(path: databaseURL.path)
        }
        try migrator.migrate(dbQueue)
    }
    
    /// Database migrations
    nonisolated private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        #if DEBUG
        // Speed up development by nuking the database when migrations change
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        
        migrator.registerMigration("v1") { db in
            // Podcasts table
            try db.create(table: "podcast") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("uuid", .text).notNull().unique()
                t.column("feedURL", .text).notNull()
                t.column("title", .text).notNull()
                t.column("author", .text)
                t.column("podcastDescription", .text)
                t.column("artworkURL", .text)
                t.column("homePageURL", .text)
                t.column("lastRefreshDate", .datetime)
                t.column("contentHash", .text)
                t.column("etag", .text)
                t.column("lastModified", .text)
                t.column("addedDate", .datetime).notNull()
                t.column("artworkColor", .text)
            }
            
            // Episodes table
            try db.create(table: "episode") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("uuid", .text).notNull().unique()
                t.column("podcastId", .integer).notNull()
                    .references("podcast", onDelete: .cascade)
                t.column("guid", .text).notNull()
                t.column("title", .text).notNull()
                t.column("episodeDescription", .text)
                t.column("audioURL", .text).notNull()
                t.column("audioMimeType", .text)
                t.column("fileSize", .integer)
                t.column("duration", .double)
                t.column("publishedDate", .datetime)
                t.column("imageURL", .text)
                t.column("episodeNumber", .integer)
                t.column("seasonNumber", .integer)
                t.column("episodeType", .text)
                
                // Playback state
                t.column("playedUpTo", .double).defaults(to: 0)
                t.column("playingStatus", .integer).defaults(to: 0)
                t.column("isDownloaded", .boolean).defaults(to: false)
                t.column("downloadedPath", .text)
            }
            
            // Indices for performance
            try db.create(index: "episode_podcastId", on: "episode", columns: ["podcastId"])
            try db.create(index: "episode_publishedDate", on: "episode", columns: ["publishedDate"])
            try db.create(index: "episode_guid_podcastId", on: "episode", columns: ["guid", "podcastId"], unique: true)
        }
        
        // Migration v2: Add download management fields
        migrator.registerMigration("v2_downloads") { db in
            try db.alter(table: "episode") { t in
                t.add(column: "downloadStatus", .integer).notNull().defaults(to: 0)
                t.add(column: "downloadProgress", .double).notNull().defaults(to: 0.0)
                t.add(column: "localFilePath", .text)
                t.add(column: "downloadedFileSize", .integer)
                t.add(column: "downloadTaskIdentifier", .text)
                t.add(column: "downloadError", .text)
                t.add(column: "autoDownloadStatus", .integer).notNull().defaults(to: 0)
            }
            
            // Create index for efficient download queries
            try db.create(index: "episode_downloadStatus", on: "episode", columns: ["downloadStatus"])
        }
        
        // Migration v3: Add extended metadata fields
        migrator.registerMigration("v3_extended_metadata") { db in
            // Add podcast extended metadata
            try db.alter(table: "podcast") { t in
                t.add(column: "language", .text)
                t.add(column: "showType", .text)
                t.add(column: "copyright", .text)
                t.add(column: "ownerName", .text)
                t.add(column: "ownerEmail", .text)
                t.add(column: "explicit", .boolean)
                t.add(column: "subtitle", .text)
                t.add(column: "fundingURL", .text)
                t.add(column: "htmlDescription", .text)
                t.add(column: "categories", .text)  // JSON array
            }
            
            // Add episode extended metadata
            try db.alter(table: "episode") { t in
                t.add(column: "link", .text)
                t.add(column: "explicit", .boolean)
                t.add(column: "subtitle", .text)
                t.add(column: "author", .text)
                t.add(column: "contentHTML", .text)
                t.add(column: "chaptersURL", .text)
                t.add(column: "transcripts", .text)  // JSON array
            }
        }
        
        // Migration v4: Add isFullyLoaded tracking for two-phase subscription
        migrator.registerMigration("v4_fully_loaded") { db in
            try db.alter(table: "podcast") { t in
                t.add(column: "isFullyLoaded", .boolean).notNull().defaults(to: true)
            }
        }
        
        // Migration v5: Add system tags and episode tagging
        migrator.registerMigration("v5_system_tags") { db in
            // Create system_tag table
            try db.create(table: "system_tag") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("uuid", .text).notNull().unique()
                t.column("type", .text).notNull()  // "mood" or "topic"
                t.column("name", .text).notNull()
                t.column("emoji", .text)
                t.column("displayOrder", .integer).notNull().defaults(to: 0)
            }
            
            // Create episode_tag junction table
            try db.create(table: "episode_tag") { t in
                t.column("episodeId", .integer).notNull()
                    .references("episode", onDelete: .cascade)
                t.column("tagId", .integer).notNull()
                    .references("system_tag", onDelete: .cascade)
                t.column("appliedAt", .datetime).notNull()
                t.primaryKey(["episodeId", "tagId"])
            }
            
            // Create indexes for efficient queries
            try db.create(index: "episode_tag_tagId", on: "episode_tag", columns: ["tagId"])
            try db.create(index: "system_tag_type_name", on: "system_tag", columns: ["type", "name"])
            
            // Seed default mood tags
            for (name, emoji, order) in SystemTagRecord.defaultMoodTags {
                var tag = SystemTagRecord(
                    type: .mood,
                    name: name,
                    emoji: emoji,
                    displayOrder: order
                )
                try tag.insert(db)
            }
            
            // Seed default topic tags
            for (name, emoji, order) in SystemTagRecord.defaultTopicTags {
                var tag = SystemTagRecord(
                    type: .topic,
                    name: name,
                    emoji: emoji,
                    displayOrder: order
                )
                try tag.insert(db)
            }
        }
        
        return migrator
    }
}

// MARK: - Database Access

extension AppDatabase {
    
    /// Read from the database
    func read<T>(_ block: (Database) throws -> T) throws -> T {
        try dbQueue.read(block)
    }
    
    /// Write to the database
    func write<T>(_ block: (Database) throws -> T) throws -> T {
        try dbQueue.write(block)
    }
    
    /// Async read from the database
    func readAsync<T: Sendable>(_ block: @Sendable @escaping (Database) throws -> T) async throws -> T {
        try await dbQueue.read(block)
    }
    
    /// Async write to the database
    func writeAsync<T: Sendable>(_ block: @Sendable @escaping (Database) throws -> T) async throws -> T {
        try await dbQueue.write(block)
    }
}
