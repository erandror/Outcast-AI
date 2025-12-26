//
//  ParentCategorySubcategoryRecord.swift
//  Outcast
//
//  GRDB record for the many-to-many relationship between parent categories and subcategories
//

import Foundation
import GRDB

/// Represents the junction table linking parent categories to their subcategories
struct ParentCategorySubcategoryRecord: Codable, Sendable, Equatable {
    var parentCategoryId: Int64
    var categoryId: Int64
    
    nonisolated init(
        parentCategoryId: Int64,
        categoryId: Int64
    ) {
        self.parentCategoryId = parentCategoryId
        self.categoryId = categoryId
    }
}

// MARK: - GRDB Protocols

extension ParentCategorySubcategoryRecord: FetchableRecord, PersistableRecord {
    nonisolated static let databaseTableName = "parent_category_subcategory"
    
    /// Association to parent category
    nonisolated static let parentCategory = belongsTo(ParentCategoryRecord.self)
    
    /// Association to category (subcategory)
    nonisolated static let category = belongsTo(CategoryRecord.self)
}

// MARK: - Database Operations

extension ParentCategorySubcategoryRecord {
    
    /// Fetch all relationships
    nonisolated static func fetchAll(db: Database) throws -> [ParentCategorySubcategoryRecord] {
        try ParentCategorySubcategoryRecord.fetchAll(db)
    }
    
    /// Fetch relationships for a specific parent category
    nonisolated static func fetchByParent(_ parentId: Int64, db: Database) throws -> [ParentCategorySubcategoryRecord] {
        try ParentCategorySubcategoryRecord
            .filter(Column("parentCategoryId") == parentId)
            .fetchAll(db)
    }
    
    /// Fetch relationships for a specific category
    nonisolated static func fetchByCategory(_ categoryId: Int64, db: Database) throws -> [ParentCategorySubcategoryRecord] {
        try ParentCategorySubcategoryRecord
            .filter(Column("categoryId") == categoryId)
            .fetchAll(db)
    }
    
    /// Check if a relationship exists
    nonisolated static func exists(parentId: Int64, categoryId: Int64, db: Database) throws -> Bool {
        try ParentCategorySubcategoryRecord
            .filter(Column("parentCategoryId") == parentId && Column("categoryId") == categoryId)
            .fetchCount(db) > 0
    }
}

