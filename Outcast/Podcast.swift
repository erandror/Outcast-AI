//
//  Podcast.swift
//  Outcast
//
//  Created by Eran Dror on 11/28/25.
//

import Foundation
import SwiftData

@Model
final class Podcast {
    var id: UUID
    var title: String
    var author: String
    var artworkColor: String // Hex color for artwork placeholder
    var episodes: [Episode]
    
    init(id: UUID = UUID(), title: String, author: String, artworkColor: String, episodes: [Episode] = []) {
        self.id = id
        self.title = title
        self.author = author
        self.artworkColor = artworkColor
        self.episodes = episodes
    }
}

@Model
final class Episode {
    var id: UUID
    var title: String
    var podcastTitle: String
    var podcastAuthor: String
    var duration: TimeInterval // in seconds
    var releaseDate: Date
    var episodeDescription: String
    var artworkColor: String
    
    init(
        id: UUID = UUID(),
        title: String,
        podcastTitle: String,
        podcastAuthor: String,
        duration: TimeInterval,
        releaseDate: Date,
        episodeDescription: String,
        artworkColor: String
    ) {
        self.id = id
        self.title = title
        self.podcastTitle = podcastTitle
        self.podcastAuthor = podcastAuthor
        self.duration = duration
        self.releaseDate = releaseDate
        self.episodeDescription = episodeDescription
        self.artworkColor = artworkColor
    }
    
    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
