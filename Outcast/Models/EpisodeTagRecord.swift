//
//  EpisodeTagRecord.swift
//  Outcast
//
//  Junction table record linking episodes to system tags
//

import Foundation
import GRDB

/// Represents the many-to-many relationship between episodes and system tags
struct EpisodeTagRecord: Codable, Sendable {
    var episodeId: Int64
    var tagId: Int64
    var appliedAt: Date
    
    init(
        episodeId: Int64,
        tagId: Int64,
        appliedAt: Date = Date()
    ) {
        self.episodeId = episodeId
        self.tagId = tagId
        self.appliedAt = appliedAt
    }
}

// MARK: - GRDB Protocols

extension EpisodeTagRecord: FetchableRecord, MutablePersistableRecord {
    nonisolated static let databaseTableName = "episode_tag"
    
    /// Define the associations
    nonisolated static let episode = belongsTo(EpisodeRecord.self)
    nonisolated static let tag = belongsTo(SystemTagRecord.self, key: "tagId")
}

// MARK: - Database Operations

extension EpisodeTagRecord {
    
    /// Add a tag to an episode (idempotent - ignores if already exists)
    static func addTag(episodeId: Int64, tagId: Int64, db: Database) throws {
        // Check if already exists
        let exists = try EpisodeTagRecord
            .filter(Column("episodeId") == episodeId && Column("tagId") == tagId)
            .fetchCount(db) > 0
        
        if !exists {
            var record = EpisodeTagRecord(episodeId: episodeId, tagId: tagId)
            try record.insert(db)
        }
    }
    
    /// Remove a tag from an episode
    static func removeTag(episodeId: Int64, tagId: Int64, db: Database) throws {
        try EpisodeTagRecord
            .filter(Column("episodeId") == episodeId && Column("tagId") == tagId)
            .deleteAll(db)
    }
    
    /// Fetch all tags for a specific episode
    static func fetchTagsForEpisode(_ episodeId: Int64, db: Database) throws -> [SystemTagRecord] {
        let request = SystemTagRecord
            .joining(required: SystemTagRecord.episodes.filter(Column("episodeId") == episodeId))
            .order(Column("type"), Column("displayOrder"))
        
        return try request.fetchAll(db)
    }
    
    /// Fetch all episode IDs that have a specific tag
    static func fetchEpisodeIdsWithTag(_ tagId: Int64, db: Database) throws -> [Int64] {
        try EpisodeTagRecord
            .select(Column("episodeId"))
            .filter(Column("tagId") == tagId)
            .fetchAll(db)
            .map { $0.episodeId }
    }
    
    /// Fetch all tags for multiple episodes (batched for efficiency)
    static func fetchTagsForEpisodes(_ episodeIds: [Int64], db: Database) throws -> [Int64: [SystemTagRecord]] {
        guard !episodeIds.isEmpty else { return [:] }
        
        let sql = """
            SELECT episode_tag.episodeId, system_tag.*
            FROM episode_tag
            INNER JOIN system_tag ON episode_tag.tagId = system_tag.id
            WHERE episode_tag.episodeId IN (\(episodeIds.map { "\($0)" }.joined(separator: ",")))
            ORDER BY system_tag.type, system_tag.displayOrder
            """
        
        let rows = try Row.fetchAll(db, sql: sql)
        
        var result: [Int64: [SystemTagRecord]] = [:]
        for row in rows {
            let episodeId: Int64 = row["episodeId"]
            let tag = try SystemTagRecord(row: row)
            result[episodeId, default: []].append(tag)
        }
        
        return result
    }
    
    /// Remove all tags from an episode
    static func removeAllTags(episodeId: Int64, db: Database) throws {
        try EpisodeTagRecord
            .filter(Column("episodeId") == episodeId)
            .deleteAll(db)
    }
    
    /// Replace all tags for an episode with a new set
    static func setTags(episodeId: Int64, tagIds: [Int64], db: Database) throws {
        print("[TAGGER] 🔍 setTags called for episodeId=\(episodeId) with \(tagIds.count) tags: \(tagIds)")
        
        // Remove all existing tags
        try removeAllTags(episodeId: episodeId, db: db)
        
        // Add new tags
        let now = Date()
        for tagId in tagIds {
            var record = EpisodeTagRecord(episodeId: episodeId, tagId: tagId, appliedAt: now)
            try record.insert(db)
            print("[TAGGER] ✅ Inserted tag \(tagId) for episode \(episodeId)")
        }
    }
    
    /// Count episodes with a specific tag
    static func countEpisodesWithTag(_ tagId: Int64, db: Database) throws -> Int {
        try EpisodeTagRecord
            .filter(Column("tagId") == tagId)
            .fetchCount(db)
    }
    
    /// Fetch tag statistics (tag name with episode count)
    static func fetchTagStatistics(type: SystemTagType? = nil, db: Database) throws -> [(tag: SystemTagRecord, count: Int)] {
        var sql = """
            SELECT system_tag.*, COUNT(episode_tag.episodeId) as episode_count
            FROM system_tag
            LEFT JOIN episode_tag ON system_tag.id = episode_tag.tagId
            """
        
        if let type = type {
            sql += " WHERE system_tag.type = '\(type.rawValue)'"
        }
        
        sql += """
            GROUP BY system_tag.id
            ORDER BY system_tag.type, system_tag.displayOrder
            """
        
        let rows = try Row.fetchAll(db, sql: sql)
        
        return try rows.map { row in
            let tag = try SystemTagRecord(row: row)
            let count: Int = row["episode_count"]
            return (tag: tag, count: count)
        }
    }
}

