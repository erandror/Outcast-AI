//
//  PlaybackContextTests.swift
//  OutcastTests
//
//  Tests for PlaybackContext and mini-player persistence
//

import Testing
import Foundation
import GRDB
@testable import Outcast

struct PlaybackContextTests {
    
    // MARK: - Setup Helper
    
    /// Create an in-memory database for testing
    func makeTestDatabase() throws -> AppDatabase {
        try AppDatabase(inMemory: true)
    }
    
    /// Create test podcast and episodes for testing
    func createTestEpisodesWithPodcast(db: AppDatabase, count: Int = 3) throws -> (podcast: PodcastRecord, episodes: [EpisodeWithPodcast]) {
        var podcast = PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "Test Podcast",
            author: "Test Author"
        )
        
        try db.write { database in
            try podcast.insert(database)
        }
        
        guard let podcastId = podcast.id else {
            throw TestError.missingId
        }
        
        var episodeRecords: [EpisodeRecord] = []
        for i in 0..<count {
            var episode = EpisodeRecord(
                podcastId: podcastId,
                guid: "ep-\(i)",
                title: "Episode \(i)",
                audioURL: "https://example.com/ep\(i).mp3",
                duration: Double(1800 + i * 300) // 30-45 min episodes
            )
            try db.write { database in
                try episode.insert(database)
            }
            episodeRecords.append(episode)
        }
        
        let episodesWithPodcast = episodeRecords.map { episode in
            EpisodeWithPodcast(episode: episode, podcast: podcast)
        }
        
        return (podcast, episodesWithPodcast)
    }
    
    // MARK: - PlaybackContext Struct Tests
    
    @Test func playbackContextStoresFilterAndEpisodes() throws {
        let db = try makeTestDatabase()
        let (_, episodes) = try createTestEpisodesWithPodcast(db: db, count: 5)
        
        let context = PlaybackContext(
            filter: .standard(.upNext),
            episodes: episodes,
            currentIndex: 2
        )
        
        #expect(context.episodes.count == 5)
        #expect(context.currentIndex == 2)
        #expect(context.filter == .standard(.upNext))
    }
    
    @Test func playbackContextCurrentEpisodeReturnsCorrectEpisode() throws {
        let db = try makeTestDatabase()
        let (_, episodes) = try createTestEpisodesWithPodcast(db: db, count: 5)
        
        let context = PlaybackContext(
            filter: .standard(.latest),
            episodes: episodes,
            currentIndex: 3
        )
        
        let currentEpisode = context.currentEpisode
        #expect(currentEpisode != nil)
        #expect(currentEpisode?.episode.guid == "ep-3")
        #expect(currentEpisode?.episode.title == "Episode 3")
    }
    
    @Test func playbackContextCurrentEpisodeReturnsNilForInvalidIndex() throws {
        let db = try makeTestDatabase()
        let (_, episodes) = try createTestEpisodesWithPodcast(db: db, count: 3)
        
        // Index too high
        var context = PlaybackContext(
            filter: .standard(.upNext),
            episodes: episodes,
            currentIndex: 10
        )
        #expect(context.currentEpisode == nil)
        
        // Negative index
        context = PlaybackContext(
            filter: .standard(.upNext),
            episodes: episodes,
            currentIndex: -1
        )
        #expect(context.currentEpisode == nil)
    }
    
    @Test func playbackContextIsIdentifiable() throws {
        let db = try makeTestDatabase()
        let (_, episodes) = try createTestEpisodesWithPodcast(db: db, count: 2)
        
        let context1 = PlaybackContext(
            filter: .standard(.upNext),
            episodes: episodes,
            currentIndex: 0
        )
        
        let context2 = PlaybackContext(
            filter: .standard(.upNext),
            episodes: episodes,
            currentIndex: 0
        )
        
        // Each context should have a unique ID
        #expect(context1.id != context2.id)
    }
    
    @Test func playbackContextIndexCanBeUpdated() throws {
        let db = try makeTestDatabase()
        let (_, episodes) = try createTestEpisodesWithPodcast(db: db, count: 5)
        
        var context = PlaybackContext(
            filter: .standard(.upNext),
            episodes: episodes,
            currentIndex: 0
        )
        
        #expect(context.currentIndex == 0)
        #expect(context.currentEpisode?.episode.guid == "ep-0")
        
        // Update index (simulating swiping to next episode)
        context.currentIndex = 2
        
        #expect(context.currentIndex == 2)
        #expect(context.currentEpisode?.episode.guid == "ep-2")
    }
    
    @Test func playbackContextEpisodesCanBeReplaced() throws {
        let db = try makeTestDatabase()
        let (podcast, originalEpisodes) = try createTestEpisodesWithPodcast(db: db, count: 3)
        
        var context = PlaybackContext(
            filter: .standard(.upNext),
            episodes: originalEpisodes,
            currentIndex: 1
        )
        
        #expect(context.episodes.count == 3)
        
        // Create new episodes (simulating filter change)
        var newEpisodes: [EpisodeWithPodcast] = []
        for i in 10..<15 {
            var episode = EpisodeRecord(
                podcastId: podcast.id!,
                guid: "new-ep-\(i)",
                title: "New Episode \(i)",
                audioURL: "https://example.com/new-ep\(i).mp3"
            )
            try db.write { database in
                try episode.insert(database)
            }
            newEpisodes.append(EpisodeWithPodcast(episode: episode, podcast: podcast))
        }
        
        // Replace episodes
        context.episodes = newEpisodes
        context.currentIndex = 0
        
        #expect(context.episodes.count == 5)
        #expect(context.currentEpisode?.episode.guid == "new-ep-10")
    }
    
    // MARK: - UserDefaults Persistence Tests
    
    @Test func lastPlayingEpisodeUUIDSavesAndRestores() throws {
        // Clear any existing value
        UserDefaults.lastPlayingEpisodeUUID = nil
        #expect(UserDefaults.lastPlayingEpisodeUUID == nil)
        
        // Save UUID
        let testUUID = "test-episode-uuid-12345"
        UserDefaults.lastPlayingEpisodeUUID = testUUID
        
        // Verify it was saved
        #expect(UserDefaults.lastPlayingEpisodeUUID == testUUID)
        
        // Clean up
        UserDefaults.lastPlayingEpisodeUUID = nil
    }
    
    @Test func lastPlayingEpisodeUUIDCanBeCleared() throws {
        // Set a value
        UserDefaults.lastPlayingEpisodeUUID = "some-uuid"
        #expect(UserDefaults.lastPlayingEpisodeUUID != nil)
        
        // Clear it
        UserDefaults.lastPlayingEpisodeUUID = nil
        #expect(UserDefaults.lastPlayingEpisodeUUID == nil)
    }
    
    // MARK: - Session Restoration Database Tests
    
    @Test func episodeCanBeFoundByUUID() throws {
        let db = try makeTestDatabase()
        let (_, episodes) = try createTestEpisodesWithPodcast(db: db, count: 3)
        
        let targetEpisode = episodes[1].episode
        
        // Find episode by UUID (simulating restore logic)
        let found = try db.read { database in
            try EpisodeRecord.filter(Column("uuid") == targetEpisode.uuid).fetchOne(database)
        }
        
        #expect(found != nil)
        #expect(found?.uuid == targetEpisode.uuid)
        #expect(found?.title == "Episode 1")
    }
    
    @Test func completedEpisodeShouldNotRestore() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "Test Podcast"
        )
        try db.write { database in
            try podcast.insert(database)
        }
        
        var episode = EpisodeRecord(
            podcastId: podcast.id!,
            guid: "ep-completed",
            title: "Completed Episode",
            audioURL: "https://example.com/completed.mp3",
            playingStatus: .completed
        )
        try db.write { database in
            try episode.insert(database)
        }
        
        // Simulating restore logic: check if episode is completed
        let found = try db.read { database in
            try EpisodeRecord.filter(Column("uuid") == episode.uuid).fetchOne(database)
        }
        
        #expect(found != nil)
        #expect(found?.playingStatus == .completed)
        
        // In restoreLastSession, this would return early without loading
        let shouldRestore = found?.playingStatus != .completed
        #expect(shouldRestore == false)
    }
    
    @Test func inProgressEpisodeShouldRestore() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "Test Podcast"
        )
        try db.write { database in
            try podcast.insert(database)
        }
        
        var episode = EpisodeRecord(
            podcastId: podcast.id!,
            guid: "ep-in-progress",
            title: "In Progress Episode",
            audioURL: "https://example.com/progress.mp3",
            playedUpTo: 600, // 10 minutes in
            playingStatus: .inProgress
        )
        try db.write { database in
            try episode.insert(database)
        }
        
        // Simulating restore logic
        let found = try db.read { database in
            try EpisodeRecord.filter(Column("uuid") == episode.uuid).fetchOne(database)
        }
        
        #expect(found != nil)
        #expect(found?.playingStatus == .inProgress)
        #expect(found?.playedUpTo == 600)
        
        // This episode should be restored
        let shouldRestore = found?.playingStatus != .completed
        #expect(shouldRestore == true)
    }
    
    @Test func notPlayedEpisodeShouldRestore() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "Test Podcast"
        )
        try db.write { database in
            try podcast.insert(database)
        }
        
        var episode = EpisodeRecord(
            podcastId: podcast.id!,
            guid: "ep-not-played",
            title: "Not Played Episode",
            audioURL: "https://example.com/notplayed.mp3",
            playingStatus: .notPlayed
        )
        try db.write { database in
            try episode.insert(database)
        }
        
        // Simulating restore logic
        let found = try db.read { database in
            try EpisodeRecord.filter(Column("uuid") == episode.uuid).fetchOne(database)
        }
        
        #expect(found != nil)
        #expect(found?.playingStatus == .notPlayed)
        
        // This episode should be restored (user may have just selected it before app closed)
        let shouldRestore = found?.playingStatus != .completed
        #expect(shouldRestore == true)
    }
    
    @Test func missingEpisodeReturnsNil() throws {
        let db = try makeTestDatabase()
        
        // Try to find non-existent episode
        let found = try db.read { database in
            try EpisodeRecord.filter(Column("uuid") == "non-existent-uuid").fetchOne(database)
        }
        
        #expect(found == nil)
    }
    
    // MARK: - EpisodeWithPodcast Fetching Tests (for context creation)
    
    @Test func fetchFilteredReturnsEpisodesForContext() throws {
        let db = try makeTestDatabase()
        
        // Create podcast with isUpNext = true
        var upNextPodcast = PodcastRecord(
            feedURL: "https://example.com/upnext.xml",
            title: "Up Next Podcast",
            isUpNext: true
        )
        try db.write { database in
            try upNextPodcast.insert(database)
        }
        
        // Create unplayed episodes for Up Next podcast
        for i in 0..<3 {
            var episode = EpisodeRecord(
                podcastId: upNextPodcast.id!,
                guid: "upnext-ep-\(i)",
                title: "Up Next Episode \(i)",
                audioURL: "https://example.com/upnext-ep\(i).mp3",
                playingStatus: .notPlayed,
                publishedDate: Date().addingTimeInterval(Double(-i * 86400)) // Staggered dates
            )
            try db.write { database in
                try episode.insert(database)
            }
        }
        
        // Fetch using the filter (simulating PlayerView context creation)
        let episodes = try db.read { database in
            try EpisodeWithPodcast.fetchFiltered(filter: .standard(.upNext), limit: 50, offset: 0, db: database)
        }
        
        #expect(episodes.count == 3)
        #expect(episodes[0].podcast.title == "Up Next Podcast")
        
        // Could be used to create a PlaybackContext
        let context = PlaybackContext(
            filter: .standard(.upNext),
            episodes: episodes,
            currentIndex: 0
        )
        
        #expect(context.currentEpisode?.episode.title == "Up Next Episode 0")
    }
    
    @Test func fetchSavedReturnsOnlySavedEpisodes() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "Test Podcast"
        )
        try db.write { database in
            try podcast.insert(database)
        }
        
        // Create saved episode
        var savedEpisode = EpisodeRecord(
            podcastId: podcast.id!,
            guid: "saved-ep",
            title: "Saved Episode",
            audioURL: "https://example.com/saved.mp3",
            isSaved: true,
            savedAt: Date()
        )
        try db.write { database in
            try savedEpisode.insert(database)
        }
        
        // Create non-saved episode
        var normalEpisode = EpisodeRecord(
            podcastId: podcast.id!,
            guid: "normal-ep",
            title: "Normal Episode",
            audioURL: "https://example.com/normal.mp3",
            isSaved: false
        )
        try db.write { database in
            try normalEpisode.insert(database)
        }
        
        // Fetch saved episodes
        let savedEpisodes = try db.read { database in
            try EpisodeWithPodcast.fetchFiltered(filter: .standard(.saved), limit: 50, offset: 0, db: database)
        }
        
        #expect(savedEpisodes.count == 1)
        #expect(savedEpisodes[0].episode.title == "Saved Episode")
        
        // Create context with saved filter
        let context = PlaybackContext(
            filter: .standard(.saved),
            episodes: savedEpisodes,
            currentIndex: 0
        )
        
        #expect(context.filter == .standard(.saved))
    }
    
    // MARK: - ListenFilter Equality Tests
    
    @Test func listenFilterEquality() throws {
        // Standard filters
        #expect(ListenFilter.standard(.upNext) == ListenFilter.standard(.upNext))
        #expect(ListenFilter.standard(.upNext) != ListenFilter.standard(.saved))
        #expect(ListenFilter.standard(.latest) == ListenFilter.standard(.latest))
    }
    
    @Test func listenFilterHashable() throws {
        var filterSet: Set<ListenFilter> = []
        
        filterSet.insert(.standard(.upNext))
        filterSet.insert(.standard(.saved))
        filterSet.insert(.standard(.upNext)) // Duplicate
        
        #expect(filterSet.count == 2) // upNext and saved, no duplicates
    }
    
    // MARK: - History Tab Navigation Tests
    // These tests verify the fix for history episodes navigation
    // Previously, tapping history episodes led to blank screens because
    // they weren't found in the Listen tab's episodes array.
    
    @Test func fetchHistoryReturnsPlayedEpisodes() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "History Test Podcast"
        )
        try db.write { database in
            try podcast.insert(database)
        }
        
        // Create episode with history (played for at least 3 minutes)
        var playedEpisode = EpisodeRecord(
            podcastId: podcast.id!,
            guid: "played-ep",
            title: "Played Episode",
            audioURL: "https://example.com/played.mp3",
            duration: 3600,
            playedUpTo: 600, // 10 minutes played (above 180s threshold)
            playingStatus: .inProgress,
            lastPlayedAt: Date()
        )
        try db.write { database in
            try playedEpisode.insert(database)
        }
        
        // Create episode without enough play time (should NOT appear in history)
        var brieflyPlayedEpisode = EpisodeRecord(
            podcastId: podcast.id!,
            guid: "brief-ep",
            title: "Briefly Played Episode",
            audioURL: "https://example.com/brief.mp3",
            duration: 3600,
            playedUpTo: 60, // Only 1 minute (below 180s threshold)
            playingStatus: .inProgress,
            lastPlayedAt: Date()
        )
        try db.write { database in
            try brieflyPlayedEpisode.insert(database)
        }
        
        // Fetch history
        let historyEpisodes = try db.read { database in
            try EpisodeWithPodcast.fetchHistory(limit: 100, db: database)
        }
        
        #expect(historyEpisodes.count == 1)
        #expect(historyEpisodes[0].episode.title == "Played Episode")
    }
    
    @Test func playbackContextCanBeCreatedFromHistoryEpisodes() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "History Podcast"
        )
        try db.write { database in
            try podcast.insert(database)
        }
        
        // Create multiple history episodes
        var historyEpisodes: [EpisodeWithPodcast] = []
        for i in 0..<5 {
            var episode = EpisodeRecord(
                podcastId: podcast.id!,
                guid: "history-ep-\(i)",
                title: "History Episode \(i)",
                audioURL: "https://example.com/history-ep\(i).mp3",
                duration: 3600,
                playedUpTo: Double(600 + i * 100), // Varying progress
                playingStatus: .inProgress,
                lastPlayedAt: Date().addingTimeInterval(Double(-i * 3600)) // Most recent first
            )
            try db.write { database in
                try episode.insert(database)
            }
            historyEpisodes.append(EpisodeWithPodcast(episode: episode, podcast: podcast))
        }
        
        // Simulate what HistoryView does when user taps play:
        // Find the episode index and create a PlaybackContext
        let targetEpisode = historyEpisodes[2]
        guard let index = historyEpisodes.firstIndex(where: { $0.id == targetEpisode.id }) else {
            Issue.record("Failed to find episode in history array")
            return
        }
        
        let context = PlaybackContext(
            filter: .standard(.latest), // History uses .latest as a fallback filter
            episodes: historyEpisodes,
            currentIndex: index
        )
        
        // Verify context is valid and usable
        #expect(context.episodes.count == 5)
        #expect(context.currentIndex == 2)
        #expect(context.currentEpisode != nil)
        #expect(context.currentEpisode?.episode.title == "History Episode 2")
    }
    
    @Test func historyContextSupportsSwipingBetweenEpisodes() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "Swipe Test Podcast"
        )
        try db.write { database in
            try podcast.insert(database)
        }
        
        // Create history episodes
        var historyEpisodes: [EpisodeWithPodcast] = []
        for i in 0..<3 {
            var episode = EpisodeRecord(
                podcastId: podcast.id!,
                guid: "swipe-ep-\(i)",
                title: "Swipe Episode \(i)",
                audioURL: "https://example.com/swipe-ep\(i).mp3",
                duration: 3600,
                playedUpTo: 600,
                playingStatus: .inProgress,
                lastPlayedAt: Date()
            )
            try db.write { database in
                try episode.insert(database)
            }
            historyEpisodes.append(EpisodeWithPodcast(episode: episode, podcast: podcast))
        }
        
        // Create context starting at first episode
        var context = PlaybackContext(
            filter: .standard(.latest),
            episodes: historyEpisodes,
            currentIndex: 0
        )
        
        #expect(context.currentEpisode?.episode.title == "Swipe Episode 0")
        
        // Simulate swiping to next episode (like in PlayerView)
        context.currentIndex = 1
        #expect(context.currentEpisode?.episode.title == "Swipe Episode 1")
        
        // Swipe again
        context.currentIndex = 2
        #expect(context.currentEpisode?.episode.title == "Swipe Episode 2")
        
        // Check bounds - can't go further
        let hasNext = context.currentIndex < context.episodes.count - 1
        #expect(hasNext == false)
    }
    
    @Test func historyContextRemainsSeparateFromListenContext() throws {
        let db = try makeTestDatabase()
        
        var podcast = PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "Test Podcast",
            isUpNext: true
        )
        try db.write { database in
            try podcast.insert(database)
        }
        
        // Create episode that appears in BOTH Up Next (unplayed) and History (played)
        // This simulates different episodes in each context
        var historyEpisode = EpisodeRecord(
            podcastId: podcast.id!,
            guid: "history-only",
            title: "History Only Episode",
            audioURL: "https://example.com/history.mp3",
            duration: 3600,
            playedUpTo: 600,
            playingStatus: .inProgress,
            lastPlayedAt: Date()
        )
        try db.write { database in
            try historyEpisode.insert(database)
        }
        
        var upNextEpisode = EpisodeRecord(
            podcastId: podcast.id!,
            guid: "upnext-only",
            title: "Up Next Only Episode",
            audioURL: "https://example.com/upnext.mp3",
            duration: 3600,
            playingStatus: .notPlayed,
            publishedDate: Date()
        )
        try db.write { database in
            try upNextEpisode.insert(database)
        }
        
        // Fetch each context's episodes
        let historyEpisodes = try db.read { database in
            try EpisodeWithPodcast.fetchHistory(limit: 100, db: database)
        }
        
        let upNextEpisodes = try db.read { database in
            try EpisodeWithPodcast.fetchFiltered(filter: .standard(.upNext), limit: 50, offset: 0, db: database)
        }
        
        // Verify they contain different episodes
        #expect(historyEpisodes.count == 1)
        #expect(historyEpisodes[0].episode.title == "History Only Episode")
        
        #expect(upNextEpisodes.count == 1)
        #expect(upNextEpisodes[0].episode.title == "Up Next Only Episode")
        
        // Create contexts from each
        let historyContext = PlaybackContext(
            filter: .standard(.latest),
            episodes: historyEpisodes,
            currentIndex: 0
        )
        
        let upNextContext = PlaybackContext(
            filter: .standard(.upNext),
            episodes: upNextEpisodes,
            currentIndex: 0
        )
        
        // Each context has its own valid episode
        #expect(historyContext.currentEpisode?.episode.title == "History Only Episode")
        #expect(upNextContext.currentEpisode?.episode.title == "Up Next Only Episode")
        
        // The bug was: history episode couldn't be found in upNext episodes
        // This proves they're separate arrays with different content
        let historyEpisodeInUpNext = upNextEpisodes.firstIndex(where: { 
            $0.id == historyEpisodes[0].id 
        })
        #expect(historyEpisodeInUpNext == nil, "History episode should NOT be in Up Next array")
    }
    
    @Test func emptyHistoryCreatesNoContext() throws {
        let db = try makeTestDatabase()
        
        // Don't create any episodes - empty history
        let historyEpisodes = try db.read { database in
            try EpisodeWithPodcast.fetchHistory(limit: 100, db: database)
        }
        
        #expect(historyEpisodes.isEmpty)
        
        // Simulating HistoryView behavior: no callback if empty
        // This prevents creating invalid contexts
        let shouldCreateContext = !historyEpisodes.isEmpty
        #expect(shouldCreateContext == false)
    }
}
