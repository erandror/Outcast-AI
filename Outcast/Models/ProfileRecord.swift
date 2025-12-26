//
//  ProfileRecord.swift
//  Outcast
//
//  GRDB record for user profile and onboarding data
//

import Foundation
import GRDB

/// Represents the user's profile in the database
struct ProfileRecord: Identifiable, Codable, Sendable {
    var id: Int64?
    var fullName: String?
    var phoneNumber: String?
    var countryCode: String?
    var selectedParentCategoryIds: [Int64]
    var selectedCategoryIds: [Int64]
    var goalAnswers: [String: Int] // goal pair key -> slider value (0-6)
    var onboardingCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    
    nonisolated init(
        id: Int64? = nil,
        fullName: String? = nil,
        phoneNumber: String? = nil,
        countryCode: String? = "+1",
        selectedParentCategoryIds: [Int64] = [],
        selectedCategoryIds: [Int64] = [],
        goalAnswers: [String: Int] = [:],
        onboardingCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.fullName = fullName
        self.phoneNumber = phoneNumber
        self.countryCode = countryCode
        self.selectedParentCategoryIds = selectedParentCategoryIds
        self.selectedCategoryIds = selectedCategoryIds
        self.goalAnswers = goalAnswers
        self.onboardingCompleted = onboardingCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - GRDB Protocols

extension ProfileRecord: FetchableRecord, MutablePersistableRecord {
    nonisolated static let databaseTableName = "user_profile"
    
    enum Columns: String, ColumnExpression {
        case id
        case fullName
        case phoneNumber
        case countryCode
        case selectedParentCategoryIds
        case selectedCategoryIds
        case goalAnswers
        case onboardingCompleted
        case createdAt
        case updatedAt
    }
    
    /// Update auto-generated id after insertion
    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    // Custom encoding/decoding for JSON columns
    nonisolated func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.fullName] = fullName
        container[Columns.phoneNumber] = phoneNumber
        container[Columns.countryCode] = countryCode
        container[Columns.onboardingCompleted] = onboardingCompleted
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        
        // Encode arrays as JSON
        if let jsonData = try? JSONEncoder().encode(selectedParentCategoryIds),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            container[Columns.selectedParentCategoryIds] = jsonString
        }
        
        if let jsonData = try? JSONEncoder().encode(selectedCategoryIds),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            container[Columns.selectedCategoryIds] = jsonString
        }
        
        if let jsonData = try? JSONEncoder().encode(goalAnswers),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            container[Columns.goalAnswers] = jsonString
        }
    }
    
    nonisolated init(row: Row) throws {
        id = row[Columns.id]
        fullName = row[Columns.fullName]
        phoneNumber = row[Columns.phoneNumber]
        countryCode = row[Columns.countryCode]
        onboardingCompleted = row[Columns.onboardingCompleted]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        
        // Decode arrays from JSON
        if let jsonString: String = row[Columns.selectedParentCategoryIds],
           let jsonData = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Int64].self, from: jsonData) {
            selectedParentCategoryIds = decoded
        } else {
            selectedParentCategoryIds = []
        }
        
        if let jsonString: String = row[Columns.selectedCategoryIds],
           let jsonData = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Int64].self, from: jsonData) {
            selectedCategoryIds = decoded
        } else {
            selectedCategoryIds = []
        }
        
        if let jsonString: String = row[Columns.goalAnswers],
           let jsonData = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: jsonData) {
            goalAnswers = decoded
        } else {
            goalAnswers = [:]
        }
    }
}

// MARK: - Database Operations

extension ProfileRecord {
    
    /// Fetch the current user's profile (assumes single user)
    nonisolated static func fetchCurrent(db: Database) throws -> ProfileRecord? {
        try ProfileRecord
            .order(Column("id").desc)
            .fetchOne(db)
    }
    
    /// Check if onboarding has been completed
    nonisolated static func isOnboardingComplete(db: Database) throws -> Bool {
        if let profile = try fetchCurrent(db: db) {
            return profile.onboardingCompleted
        }
        return false
    }
    
    /// Save or update the user profile
    nonisolated static func saveProfile(
        fullName: String?,
        phoneNumber: String?,
        countryCode: String?,
        selectedParentCategoryIds: [Int64],
        selectedCategoryIds: [Int64],
        goalAnswers: [String: Int],
        onboardingCompleted: Bool,
        db: Database
    ) throws {
        var profile: ProfileRecord
        
        if let existing = try fetchCurrent(db: db) {
            // Update existing profile
            profile = existing
            profile.fullName = fullName
            profile.phoneNumber = phoneNumber
            profile.countryCode = countryCode
            profile.selectedParentCategoryIds = selectedParentCategoryIds
            profile.selectedCategoryIds = selectedCategoryIds
            profile.goalAnswers = goalAnswers
            profile.onboardingCompleted = onboardingCompleted
            profile.updatedAt = Date()
            try profile.update(db)
        } else {
            // Create new profile
            profile = ProfileRecord(
                fullName: fullName,
                phoneNumber: phoneNumber,
                countryCode: countryCode,
                selectedParentCategoryIds: selectedParentCategoryIds,
                selectedCategoryIds: selectedCategoryIds,
                goalAnswers: goalAnswers,
                onboardingCompleted: onboardingCompleted,
                createdAt: Date(),
                updatedAt: Date()
            )
            try profile.insert(db)
        }
    }
}

