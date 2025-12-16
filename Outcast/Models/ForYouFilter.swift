//
//  ForYouFilter.swift
//  Outcast
//
//  Filter types for the For You page with category and keyword matching
//

import Foundation

/// Filter options for the For You page
enum ForYouFilter: String, CaseIterable, Sendable {
    case upNext
    case saved
    case latest
    case short
    case friendly
    case funny
    case interesting
    case captivating
    case conversations
    case timely
    
    /// Emoji icon for the filter
    var emoji: String {
        switch self {
        case .upNext: return "⏭️"
        case .saved: return "🔖"
        case .latest: return "🆕"
        case .short: return "⚡"
        case .friendly: return "☀️"
        case .funny: return "😂"
        case .interesting: return "🤔"
        case .captivating: return "🎭"
        case .conversations: return "💬"
        case .timely: return "📰"
        }
    }
    
    /// Display label for the filter
    var label: String {
        switch self {
        case .upNext: return "Up Next"
        case .saved: return "Saved"
        case .latest: return "Latest"
        case .short: return "Short"
        case .friendly: return "Friendly"
        case .funny: return "Funny"
        case .interesting: return "Interesting"
        case .captivating: return "Captivating"
        case .conversations: return "Conversations"
        case .timely: return "Timely"
        }
    }
    
    /// iTunes/Apple Podcasts categories that match this filter
    var categories: [String] {
        switch self {
        case .upNext, .saved, .latest, .short:
            return []
        case .friendly:
            return ["Personal Journals", "Self-Improvement", "Relationships", "Leisure"]
        case .funny:
            return ["Comedy"]
        case .interesting:
            return ["Science", "Technology", "Education", "History", "Nature"]
        case .captivating:
            return ["Fiction", "True Crime", "Documentary", "Drama"]
        case .conversations:
            return ["Society & Culture"]
        case .timely:
            return ["News", "Government", "Politics"]
        }
    }
    
    /// Keywords to search for in titles and descriptions (case-insensitive)
    var keywords: [String] {
        switch self {
        case .upNext, .saved, .latest, .short:
            return []
        case .friendly:
            return ["friends", "chat", "cozy", "casual", "vibes", "hang out", "chill"]
        case .funny:
            return ["comedy", "comedian", "funny", "humor", "humour", "laugh", "hilarious", "jokes", "stand-up", "improv"]
        case .interesting:
            return ["curious", "fascinating", "explain", "discover", "wonder", "learn", "how", "why"]
        case .captivating:
            return ["story", "stories", "narrative", "mystery", "thriller", "investigation", "documentary"]
        case .conversations:
            return ["interview", "conversation", "guest", "talks to", "sits down", "speaks with", "chat with"]
        case .timely:
            return ["news", "daily", "today", "this week", "headlines", "update", "briefing", "current events"]
        }
    }
    
    /// Keywords to exclude (for negative filtering)
    var excludeKeywords: [String] {
        switch self {
        case .interesting:
            // Exclude news-related content from Interesting
            return ["news", "headlines", "breaking", "daily briefing"]
        default:
            return []
        }
    }
    
    /// Whether this filter uses showType == "serial"
    var requiresSerial: Bool {
        self == .captivating
    }
    
    /// Whether this filter checks for populated episode author (indicates guest)
    var requiresEpisodeAuthor: Bool {
        self == .conversations
    }
    
    /// Mood tag name for tag-based filtering
    /// Returns the corresponding mood tag name for filters that use system tags
    var moodTagName: String? {
        switch self {
        case .friendly:
            return "Warm"
        case .funny:
            return "Funny"
        case .interesting:
            return "Interesting"
        case .captivating:
            return "Captivating"
        case .conversations:
            return "Conversations"
        case .timely:
            return "Timely"
        case .upNext, .saved, .latest, .short:
            return nil
        }
    }
}
