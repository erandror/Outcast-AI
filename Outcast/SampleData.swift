//
//  SampleData.swift
//  Outcast
//
//  Created by Eran Dror on 11/28/25.
//

import Foundation
import SwiftData

struct SampleData {
    static func createSampleEpisodes(in modelContext: ModelContext) {
        // Check if we already have episodes
        let descriptor = FetchDescriptor<Episode>()
        let existingEpisodes = try? modelContext.fetch(descriptor)
        if let episodes = existingEpisodes, !episodes.isEmpty {
            return // Data already exists
        }
        
        // Sample episodes with variety
        let episodes = [
            Episode(
                title: "The Future of AI and Creativity",
                podcastTitle: "Tech Horizons",
                podcastAuthor: "Sarah Chen",
                duration: 2847, // 47 minutes
                releaseDate: Date().addingTimeInterval(-86400 * 1), // 1 day ago
                episodeDescription: "Exploring how artificial intelligence is reshaping creative industries and what it means for human artists.",
                artworkColor: "#FF6B35"
            ),
            Episode(
                title: "Understanding Quantum Computing",
                podcastTitle: "Science Simplified",
                podcastAuthor: "Dr. James Morrison",
                duration: 3621, // 1 hour 21 minutes
                releaseDate: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                episodeDescription: "Breaking down the complex world of quantum computing into digestible concepts.",
                artworkColor: "#4ECDC4"
            ),
            Episode(
                title: "The Art of Minimalist Living",
                podcastTitle: "Life Redesigned",
                podcastAuthor: "Maya Patel",
                duration: 1923, // 32 minutes
                releaseDate: Date().addingTimeInterval(-86400 * 3), // 3 days ago
                episodeDescription: "Practical tips for decluttering your life and focusing on what truly matters.",
                artworkColor: "#95E1D3"
            ),
            Episode(
                title: "Building Better Habits",
                podcastTitle: "Mind Mastery",
                podcastAuthor: "Alex Rodriguez",
                duration: 2156, // 35 minutes
                releaseDate: Date().addingTimeInterval(-86400 * 4),
                episodeDescription: "The science behind habit formation and practical strategies for lasting change.",
                artworkColor: "#F38181"
            ),
            Episode(
                title: "The History of Jazz: Part 5",
                podcastTitle: "Musical Journeys",
                podcastAuthor: "Marcus Williams",
                duration: 4231, // 1 hour 10 minutes
                releaseDate: Date().addingTimeInterval(-86400 * 5),
                episodeDescription: "Diving into the bebop era and its revolutionary impact on modern music.",
                artworkColor: "#AA96DA"
            ),
            Episode(
                title: "Startup Failures and Lessons Learned",
                podcastTitle: "Founder Stories",
                podcastAuthor: "Jennifer Liu",
                duration: 3142, // 52 minutes
                releaseDate: Date().addingTimeInterval(-86400 * 6),
                episodeDescription: "Candid conversations with founders about their biggest mistakes and comebacks.",
                artworkColor: "#FCBAD3"
            ),
            Episode(
                title: "Climate Change: What You Can Do Today",
                podcastTitle: "Our Planet",
                podcastAuthor: "Dr. Emma Thompson",
                duration: 2634, // 43 minutes
                releaseDate: Date().addingTimeInterval(-86400 * 7),
                episodeDescription: "Actionable steps individuals can take to reduce their carbon footprint.",
                artworkColor: "#A8D8EA"
            ),
            Episode(
                title: "The Psychology of Money",
                podcastTitle: "Wealth Wisdom",
                podcastAuthor: "David Park",
                duration: 2891, // 48 minutes
                releaseDate: Date().addingTimeInterval(-86400 * 8),
                episodeDescription: "Understanding the emotional and psychological factors that influence financial decisions.",
                artworkColor: "#FFFFD2"
            )
        ]
        
        // Insert all episodes
        episodes.forEach { modelContext.insert($0) }
        
        // Save the context
        try? modelContext.save()
    }
}
