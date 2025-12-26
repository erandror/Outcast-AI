//
//  CategoryRecord.swift
//  Outcast
//
//  GRDB record for categories (podcast subcategories)
//

import Foundation
import GRDB

/// Represents a category (subcategory) in the database
struct CategoryRecord: Identifiable, Codable, Sendable, Equatable {
    var id: Int64?
    var label: String
    var emoji: String
    var genreId: Int?      // Apple's genre identifier (if top-level)
    var subgenreId: Int?   // Apple's subgenre identifier
    
    nonisolated init(
        id: Int64? = nil,
        label: String,
        emoji: String,
        genreId: Int? = nil,
        subgenreId: Int? = nil
    ) {
        self.id = id
        self.label = label
        self.emoji = emoji
        self.genreId = genreId
        self.subgenreId = subgenreId
    }
}

// MARK: - GRDB Protocols

extension CategoryRecord: FetchableRecord, MutablePersistableRecord {
    nonisolated static let databaseTableName = "category"
    
    /// Update auto-generated id after insertion
    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    /// Parent categories association (via junction table)
    nonisolated static let parentCategories = hasMany(
        ParentCategorySubcategoryRecord.self,
        key: "parentCategories"
    )
}

// MARK: - Database Operations

extension CategoryRecord {
    
    /// Fetch all categories ordered by label
    nonisolated static func fetchAll(db: Database) throws -> [CategoryRecord] {
        try CategoryRecord
            .order(Column("label").collating(.localizedCaseInsensitiveCompare))
            .fetchAll(db)
    }
    
    /// Fetch categories for a specific parent category
    nonisolated static func fetchByParent(_ parentId: Int64, db: Database) throws -> [CategoryRecord] {
        try CategoryRecord
            .joining(required: CategoryRecord.parentCategories.filter(Column("parentCategoryId") == parentId))
            .order(Column("label").collating(.localizedCaseInsensitiveCompare))
            .fetchAll(db)
    }
    
    /// Fetch a category by its subgenre ID
    nonisolated static func fetchBySubgenreId(_ subgenreId: Int, db: Database) throws -> CategoryRecord? {
        try CategoryRecord
            .filter(Column("subgenreId") == subgenreId)
            .fetchOne(db)
    }
    
    /// Fetch a category by its genre ID (for top-level categories)
    nonisolated static func fetchByGenreId(_ genreId: Int, db: Database) throws -> CategoryRecord? {
        try CategoryRecord
            .filter(Column("genreId") == genreId)
            .fetchOne(db)
    }
    
    /// Fetch a category by its label
    nonisolated static func fetchByLabel(_ label: String, db: Database) throws -> CategoryRecord? {
        try CategoryRecord
            .filter(Column("label") == label)
            .fetchOne(db)
    }
    
    /// Fetch category by ID
    nonisolated static func fetchById(_ id: Int64, db: Database) throws -> CategoryRecord? {
        try CategoryRecord
            .filter(Column("id") == id)
            .fetchOne(db)
    }
}

