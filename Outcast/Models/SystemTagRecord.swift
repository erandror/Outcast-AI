//
//  SystemTagRecord.swift
//  Outcast
//
//  GRDB record for system-defined tags (mood and topic)
//

import Foundation
import GRDB

/// Type of system tag
enum SystemTagType: String, Codable, Sendable {
    case mood = "mood"
    case topic = "topic"
}

/// Represents a system-defined tag in the database
struct SystemTagRecord: Identifiable, Codable, Sendable, Equatable {
    var id: Int64?
    var uuid: String
    var type: SystemTagType
    var name: String
    var emoji: String?
    var displayOrder: Int
    
    nonisolated init(
        id: Int64? = nil,
        uuid: String = UUID().uuidString,
        type: SystemTagType,
        name: String,
        emoji: String? = nil,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.uuid = uuid
        self.type = type
        self.name = name
        self.emoji = emoji
        self.displayOrder = displayOrder
    }
}

// MARK: - GRDB Protocols

extension SystemTagRecord: FetchableRecord, MutablePersistableRecord {
    nonisolated static let databaseTableName = "system_tag"
    
    /// Update auto-generated id after insertion
    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    /// Episodes association (via junction table)
    nonisolated static let episodes = hasMany(EpisodeTagRecord.self)
}

// MARK: - Database Operations

extension SystemTagRecord {
    
    /// Fetch all tags of a specific type, ordered by displayOrder
    static func fetchByType(_ type: SystemTagType, db: Database) throws -> [SystemTagRecord] {
        try SystemTagRecord
            .filter(Column("type") == type.rawValue)
            .order(Column("displayOrder"))
            .fetchAll(db)
    }
    
    /// Fetch all mood tags
    static func fetchMoodTags(db: Database) throws -> [SystemTagRecord] {
        try fetchByType(.mood, db: db)
    }
    
    /// Fetch all topic tags
    static func fetchTopicTags(db: Database) throws -> [SystemTagRecord] {
        try fetchByType(.topic, db: db)
    }
    
    /// Fetch a tag by name and type
    static func fetchByName(_ name: String, type: SystemTagType, db: Database) throws -> SystemTagRecord? {
        try SystemTagRecord
            .filter(Column("name") == name && Column("type") == type.rawValue)
            .fetchOne(db)
    }
    
    /// Fetch all tags
    static func fetchAll(db: Database) throws -> [SystemTagRecord] {
        try SystemTagRecord
            .order(Column("type"), Column("displayOrder"))
            .fetchAll(db)
    }
}

// MARK: - Default Tag Definitions

extension SystemTagRecord {
    
    /// Default mood tags to seed
    nonisolated static let defaultMoodTags: [(name: String, emoji: String?, order: Int)] = [
        ("Warm", "☀️", 0),
        ("Connected", "🤝", 1),
        ("Funny", "😂", 2),
        ("Interesting", "🤔", 3),
        ("Captivating", "🎭", 4),
        ("Conversations", "💬", 5),
        ("Timely", "📰", 6),
        ("Informative", "📚", 7),
        ("Inspiring", "✨", 8),
        ("Calming", "🧘", 9),
        ("Joyful", "🎉", 10),
        ("Thoughtful", "💭", 11)
    ]
    
    /// Default topic tags to seed
    nonisolated static let defaultTopicTags: [(name: String, emoji: String?, order: Int)] = [
        // Arts & Entertainment
        ("Arts & Entertainment", "🎨", 0),
        ("Books", "📖", 1),
        ("Celebrities", "⭐", 2),
        ("Comedy", "🎭", 3),
        ("Design", "🎨", 4),
        ("Fiction", "📚", 5),
        ("Film", "🎬", 6),
        ("Literature", "📕", 7),
        ("Pop Culture", "🎪", 8),
        ("Stories", "📖", 9),
        ("TV", "📺", 10),
        
        // Business & Technology
        ("Business & Technology", "💼", 11),
        ("Business", "💼", 12),
        ("Careers", "👔", 13),
        ("Economics", "📈", 14),
        ("Finance", "💰", 15),
        ("Marketing", "📢", 16),
        ("Technology", "💻", 17),
        
        // Educational
        ("Educational", "🎓", 18),
        ("Government", "🏛️", 19),
        ("History", "📜", 20),
        ("Language", "🗣️", 21),
        ("Philosophy", "🤔", 22),
        ("Science", "🔬", 23),
        
        // Games
        ("Games", "🎮", 24),
        ("Video games", "🕹️", 25),
        
        // Lifestyle & Health
        ("Lifestyle & Health", "🌱", 26),
        ("Beauty", "💄", 27),
        ("Fashion", "👗", 28),
        ("Fitness & Nutrition", "🏋️", 29),
        ("Food", "🍽️", 30),
        ("Health", "❤️", 31),
        ("Hobbies", "🎨", 32),
        ("Lifestyle", "🌟", 33),
        ("Meditation Podcasts", "🧘", 34),
        ("Parenting", "👨‍👩‍👧‍👦", 35),
        ("Relationships", "💑", 36),
        ("Self-care", "🛀", 37),
        ("Sex", "💕", 38),
        
        // News & Politics
        ("News & Politics", "📰", 39),
        ("Politics", "🏛️", 40),
        
        // Sports & Recreation
        ("Sports & Recreation", "⚽", 41),
        ("Baseball", "⚾", 42),
        ("Basketball", "🏀", 43),
        ("Boxing", "🥊", 44),
        ("Football", "🏈", 45),
        ("Hockey", "🏒", 46),
        ("MMA", "🥋", 47),
        ("Outdoor", "🏔️", 48),
        ("Rugby", "🏉", 49),
        ("Running", "🏃", 50),
        ("Soccer", "⚽", 51),
        ("Tennis", "🎾", 52),
        ("Wrestling", "🤼", 53),
        
        // True Crime
        ("True Crime", "🔍", 54)
    ]
}

