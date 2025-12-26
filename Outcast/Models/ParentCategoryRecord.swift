//
//  ParentCategoryRecord.swift
//  Outcast
//
//  GRDB record for parent categories (top-level podcast categories)
//

import Foundation
import GRDB

/// Represents a parent category in the database
struct ParentCategoryRecord: Identifiable, Codable, Sendable, Equatable {
    var id: Int64?
    var label: String
    var emoji: String
    var genreId: Int?  // Apple's genre identifier
    
    nonisolated init(
        id: Int64? = nil,
        label: String,
        emoji: String,
        genreId: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.emoji = emoji
        self.genreId = genreId
    }
}

// MARK: - GRDB Protocols

extension ParentCategoryRecord: FetchableRecord, MutablePersistableRecord {
    nonisolated static let databaseTableName = "parent_category"
    
    /// Update auto-generated id after insertion
    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    /// Subcategories association (via junction table)
    nonisolated static let subcategories = hasMany(
        ParentCategorySubcategoryRecord.self,
        key: "subcategories"
    )
}

// MARK: - Database Operations

extension ParentCategoryRecord {
    
    /// Fetch all parent categories ordered by label
    nonisolated static func fetchAll(db: Database) throws -> [ParentCategoryRecord] {
        try ParentCategoryRecord
            .order(Column("label").collating(.localizedCaseInsensitiveCompare))
            .fetchAll(db)
    }
    
    /// Fetch a parent category by its genre ID
    nonisolated static func fetchByGenreId(_ genreId: Int, db: Database) throws -> ParentCategoryRecord? {
        try ParentCategoryRecord
            .filter(Column("genreId") == genreId)
            .fetchOne(db)
    }
    
    /// Fetch a parent category by its label
    nonisolated static func fetchByLabel(_ label: String, db: Database) throws -> ParentCategoryRecord? {
        try ParentCategoryRecord
            .filter(Column("label") == label)
            .fetchOne(db)
    }
    
    /// Fetch parent category by ID
    nonisolated static func fetchById(_ id: Int64, db: Database) throws -> ParentCategoryRecord? {
        try ParentCategoryRecord
            .filter(Column("id") == id)
            .fetchOne(db)
    }
}

