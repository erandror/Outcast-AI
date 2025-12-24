//
//  DatabaseTests.swift
//  OutcastTests
//
//  Tests for database operations using in-memory database
//

import Testing
import Foundation
import GRDB
@testable import Outcast

struct DatabaseTests {
    
    // MARK: - Setup Helper
    
    /// Create an in-memory database for testing
    func makeTestDatabase() throws -> AppDatabase {
        try AppDatabase(inMemory: true)
    }
    
    // MARK: - Podcast CRUD Tests
    
    @Test func insertAndFetchPodcast() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "Test Podcast",
            author: "Test Author",
            podcastDescription: "Test description"
        )
        
        try db.write { database in
            try podcast.insert(database)
        }
        
        let fetched = try db.read { database in
            try PodcastRecord.fetchByFeedURL("https://example.com/feed.xml", db: database)
        }
        
        #expect(fetched != nil)
        #expect(fetched?.title == "Test Podcast")
        #expect(fetched?.author == "Test Author")
        #expect(fetched?.feedURL == "https://example.com/feed.xml")
        #expect(fetched?.id != nil)
    }
    
    @Test func insertAndFetchEpisode() throws {
        let db = try makeTestDatabase()
        
        // First insert a podcast
        var podcast = PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "Test Podcast"
        )
        
        try db.write { database in
            try podcast.insert(database)
        }
        
        guard let podcastId = podcast.id else {
            throw TestError.missingId
        }
        
        // Then insert an episode
        var episode = EpisodeRecord(
            podcastId: podcastId,
            guid: "ep-001",
            title: "Test Episode",
            episodeDescription: "Test description",
            audioURL: "https://example.com/ep1.mp3"
        )
        
        try db.write { database in
            try episode.insert(database)
        }
        
        // Fetch episodes for the podcast
        let episodes = try db.read { database in
            try EpisodeRecord.fetchAllForPodcast(podcastId, db: database)
        }
        
        #expect(episodes.count == 1)
        #expect(episodes[0].title == "Test Episode")
        #expect(episodes[0].guid == "ep-001")
        #expect(episodes[0].podcastId == podcastId)
    }
    
    @Test func fetchByFeedURL() throws {
        let db = try makeTestDatabase()
        
        var podcast1 = PodcastRecord(feedURL: "https://example.com/feed1.xml", title: "Podcast 1")
        var podcast2 = PodcastRecord(feedURL: "https://example.com/feed2.xml", title: "Podcast 2")
        
        try db.write { database in
            try podcast1.insert(database)
            try podcast2.insert(database)
        }
        
        let fetched = try db.read { database in
            try PodcastRecord.fetchByFeedURL("https://example.com/feed2.xml", db: database)
        }
        
        #expect(fetched?.title == "Podcast 2")
    }
    
    @Test func cascadeDeleteEpisodes() throws {
        let db = try makeTestDatabase()
        
        // Insert podcast with episodes
        var podcast = PodcastRecord(feedURL: "https://example.com/feed.xml", title: "Test Podcast")
        try db.write { database in
            try podcast.insert(database)
        }
        
        guard let podcastId = podcast.id else {
            throw TestError.missingId
        }
        
        var episode1 = EpisodeRecord(podcastId: podcastId, guid: "ep-1", title: "Episode 1", audioURL: "https://example.com/ep1.mp3")
        var episode2 = EpisodeRecord(podcastId: podcastId, guid: "ep-2", title: "Episode 2", audioURL: "https://example.com/ep2.mp3")
        
        try db.write { database in
            try episode1.insert(database)
            try episode2.insert(database)
        }
        
        // Verify episodes exist
        let beforeDelete = try db.read { database in
            try EpisodeRecord.fetchAllForPodcast(podcastId, db: database)
        }
        #expect(beforeDelete.count == 2)
        
        // Delete podcast
        try db.write { database in
            try podcast.deleteWithEpisodes(db: database)
        }
        
        // Verify episodes were cascaded deleted
        let afterDelete = try db.read { database in
            try EpisodeRecord.fetchAllForPodcast(podcastId, db: database)
        }
        #expect(afterDelete.count == 0)
    }
    
    @Test func fetchUnplayedEpisodes() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(feedURL: "https://example.com/feed.xml", title: "Test Podcast")
        try db.write { database in
            try podcast.insert(database)
        }
        
        guard let podcastId = podcast.id else {
            throw TestError.missingId
        }
        
        var unplayed = EpisodeRecord(
            podcastId: podcastId,
            guid: "unplayed",
            title: "Unplayed",
            audioURL: "https://example.com/unplayed.mp3",
            playingStatus: .notPlayed
        )
        
        var inProgress = EpisodeRecord(
            podcastId: podcastId,
            guid: "in-progress",
            title: "In Progress",
            audioURL: "https://example.com/progress.mp3",
            playingStatus: .inProgress
        )
        
        try db.write { database in
            try unplayed.insert(database)
            try inProgress.insert(database)
        }
        
        let unplayedEpisodes = try db.read { database in
            try EpisodeRecord.fetchUnplayed(db: database)
        }
        
        #expect(unplayedEpisodes.count == 1)
        #expect(unplayedEpisodes[0].title == "Unplayed")
    }
    
    @Test func fetchHistory() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(feedURL: "https://example.com/feed.xml", title: "Test Podcast")
        try db.write { database in
            try podcast.insert(database)
        }
        
        guard let podcastId = podcast.id else {
            throw TestError.missingId
        }
        
        // Episode with significant playback
        var played = EpisodeRecord(
            podcastId: podcastId,
            guid: "played",
            title: "Played Episode",
            audioURL: "https://example.com/played.mp3",
            playedUpTo: 300, // 5 minutes
            lastPlayedAt: Date()
        )
        
        // Episode with minimal playback (should not appear in history)
        var minimal = EpisodeRecord(
            podcastId: podcastId,
            guid: "minimal",
            title: "Minimal",
            audioURL: "https://example.com/minimal.mp3",
            playedUpTo: 30, // 30 seconds
            lastPlayedAt: Date()
        )
        
        try db.write { database in
            try played.insert(database)
            try minimal.insert(database)
        }
        
        let history = try db.read { database in
            try EpisodeRecord.fetchHistory(db: database)
        }
        
        // Only episode with >= 180 seconds should appear
        #expect(history.count == 1)
        #expect(history[0].title == "Played Episode")
    }
    
    @Test func updatePlaybackPosition() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(feedURL: "https://example.com/feed.xml", title: "Test Podcast")
        try db.write { database in
            try podcast.insert(database)
        }
        
        guard let podcastId = podcast.id else {
            throw TestError.missingId
        }
        
        var episode = EpisodeRecord(
            podcastId: podcastId,
            guid: "ep-1",
            title: "Test Episode",
            audioURL: "https://example.com/ep1.mp3"
        )
        
        try db.write { database in
            try episode.insert(database)
        }
        
        // Update playback position
        try db.write { database in
            try episode.updatePlaybackPosition(150.0, db: database)
        }
        
        // Fetch and verify
        let updated = try db.read { database in
            try EpisodeRecord.fetchByGuid("ep-1", podcastId: podcastId, db: database)
        }
        
        #expect(updated?.playedUpTo == 150.0)
        #expect(updated?.playingStatus == .inProgress)
    }
    
    @Test func systemTagSeeding() throws {
        let db = try makeTestDatabase()
        
        // Migration v5 should have seeded system tags
        let moodTags = try db.read { database in
            try SystemTagRecord.fetchMoodTags(db: database)
        }
        
        let topicTags = try db.read { database in
            try SystemTagRecord.fetchTopicTags(db: database)
        }
        
        // Verify default tags were seeded
        #expect(moodTags.count == 12) // From SystemTagRecord.defaultMoodTags
        #expect(topicTags.count == 55) // From SystemTagRecord.defaultTopicTags
        
        // Verify specific tags exist
        let warmTag = moodTags.first { $0.name == "Warm" }
        #expect(warmTag != nil)
        #expect(warmTag?.emoji == "☀️")
        
        let techTag = topicTags.first { $0.name == "Technology" }
        #expect(techTag != nil)
    }
    
    @Test func episodeTagAssociation() throws {
        let db = try makeTestDatabase()
        
        // Insert podcast and episode
        var podcast = PodcastRecord(feedURL: "https://example.com/feed.xml", title: "Test Podcast")
        try db.write { database in
            try podcast.insert(database)
        }
        
        guard let podcastId = podcast.id else {
            throw TestError.missingId
        }
        
        var episode = EpisodeRecord(
            podcastId: podcastId,
            guid: "ep-1",
            title: "Test Episode",
            audioURL: "https://example.com/ep1.mp3"
        )
        
        try db.write { database in
            try episode.insert(database)
        }
        
        guard let episodeId = episode.id else {
            throw TestError.missingId
        }
        
        // Get some system tags
        let tags = try db.read { database in
            try SystemTagRecord.fetchMoodTags(db: database)
        }
        
        guard tags.count >= 2 else {
            throw TestError.missingTags
        }
        
        let tagIds = tags.prefix(2).compactMap { $0.id }
        
        // Apply tags
        try db.write { database in
            try EpisodeTagRecord.setTags(episodeId: episodeId, tagIds: tagIds, db: database)
        }
        
        // Fetch episode tags
        let episodeTags = try db.read { database in
            try EpisodeTagRecord
                .filter(Column("episodeId") == episodeId)
                .fetchAll(database)
        }
        
        #expect(episodeTags.count == 2)
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case missingId
    case missingTags
}
