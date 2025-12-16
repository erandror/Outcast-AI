//
//  ShowsFilter.swift
//  Outcast
//
//  Filter types for the Shows page
//

import Foundation

/// Filter options for the Shows page
enum ShowsFilter: String, CaseIterable, Sendable {
    case allShows
    case upNext
    
    /// Display label for the filter
    var label: String {
        switch self {
        case .allShows:
            return "All Shows"
        case .upNext:
            return "Up Next"
        }
    }
    
    /// Emoji icon for the filter
    var emoji: String {
        switch self {
        case .allShows:
            return "📚"
        case .upNext:
            return "⏭️"
        }
    }
}

