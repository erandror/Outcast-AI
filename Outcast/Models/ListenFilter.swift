//
//  ListenFilter.swift
//  Outcast
//
//  Unified filter model for Listen tab (topics + standard mood/time filters)
//

import Foundation

/// Filter options for the Listen tab
/// Supports both standard filters (mood/time-based) and dynamic topic filters
enum ListenFilter: Identifiable, Sendable {
    case standard(ForYouFilter)
    case topic(SystemTagRecord)
    
    var id: String {
        switch self {
        case .standard(let filter):
            return "standard_\(filter.rawValue)"
        case .topic(let tag):
            return "topic_\(tag.uuid)"
        }
    }
}

// MARK: - Hashable & Equatable (based on id)

extension ListenFilter: Hashable, Equatable {
    static func == (lhs: ListenFilter, rhs: ListenFilter) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var emoji: String {
        switch self {
        case .standard(let filter):
            return filter.emoji
        case .topic(let tag):
            return tag.emoji ?? "🏷️"
        }
    }
    
    var label: String {
        switch self {
        case .standard(let filter):
            return filter.label
        case .topic(let tag):
            return tag.name
        }
    }
    
    /// The underlying ForYouFilter if this is a standard filter
    var forYouFilter: ForYouFilter? {
        if case .standard(let filter) = self {
            return filter
        }
        return nil
    }
    
    /// The underlying SystemTagRecord if this is a topic filter
    var topicTag: SystemTagRecord? {
        if case .topic(let tag) = self {
            return tag
        }
        return nil
    }
}

