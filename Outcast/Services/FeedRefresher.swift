//
//  FeedRefresher.swift
//  Outcast
//
//  Service for fetching and refreshing podcast feeds
//  Inspired by NetNewsWire's LocalAccountRefresher (MIT License)
//

import Foundation
import GRDB

/// Manages podcast feed refresh operations
actor FeedRefresher {
    
    /// Shared instance
    static let shared = FeedRefresher(database: AppDatabase.shared)
    
    private let database: AppDatabase
    private let urlSession: URLSession
    private var isRefreshing = false
    
    init(database: AppDatabase) {
        self.database = database
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
    }
    
    /// Refresh all podcast feeds
    /// - Returns: Number of new episodes found
    @discardableResult
    func refreshAll() async throws -> Int {
        guard !isRefreshing else { return 0 }
        isRefreshing = true
        defer { isRefreshing = false }
        
        let podcasts = try await database.readAsync { db in
            try PodcastRecord.fetchAll(db)
        }
        
        // Prioritize Up Next podcasts for faster refresh
        let upNextPodcasts = podcasts.filter { $0.isUpNext }
        let otherPodcasts = podcasts.filter { !$0.isUpNext }
        let orderedPodcasts = upNextPodcasts + otherPodcasts
        
        var totalNewEpisodes = 0
        
        // Refresh feeds concurrently but with a limit
        await withTaskGroup(of: Int.self) { group in
            for podcast in orderedPodcasts {
                group.addTask {
                    do {
                        return try await self.refresh(podcast: podcast)
                    } catch {
                        print("Failed to refresh \(podcast.title): \(error)")
                        return 0
                    }
                }
            }
            
            for await newCount in group {
                totalNewEpisodes += newCount
            }
        }
        
        // Update global last refresh timestamp
        UserDefaults.lastFeedRefresh = Date()
        
        return totalNewEpisodes
    }
    
    /// Refresh a single podcast feed
    /// - Parameter podcast: The podcast to refresh
    /// - Returns: Number of new episodes found
    @discardableResult
    func refresh(podcast: PodcastRecord) async throws -> Int {
        guard let url = URL(string: podcast.feedURL) else {
            throw FeedParserError.invalidData
        }
        
        // Build request with conditional GET headers
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Outcast/1.0", forHTTPHeaderField: "User-Agent")
        
        // Conditional GET for efficiency
        if let etag = podcast.etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified = podcast.lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedParserError.networkError(URLError(.badServerResponse))
        }
        
        // Handle 304 Not Modified
        if httpResponse.statusCode == 304 {
            // Update last refresh date only
            try await database.writeAsync { db in
                var updatedPodcast = podcast
                updatedPodcast.lastRefreshDate = Date()
                try updatedPodcast.update(db)
            }
            return 0
        }
        
        guard httpResponse.statusCode == 200 else {
            throw FeedParserError.networkError(URLError(.badServerResponse))
        }
        
        // Check if content has changed
        let contentHash = data.md5Hash
        if podcast.contentHash == contentHash {
            try await database.writeAsync { db in
                var updatedPodcast = podcast
                updatedPodcast.lastRefreshDate = Date()
                try updatedPodcast.update(db)
            }
            return 0
        }
        
        // Parse the feed
        let parser = FeedParser()
        let parseResult = try parser.parse(data: data)
        let parsedFeed = parseResult.podcast
        
        // Update podcast and save new episodes
        let (newEpisodeCount, newEpisodeIds) = try await database.writeAsync { db -> (Int, [Int64]) in
            // Update podcast metadata
            var updatedPodcast = podcast
            updatedPodcast.title = parsedFeed.title
            updatedPodcast.author = parsedFeed.author
            updatedPodcast.podcastDescription = parsedFeed.description
            updatedPodcast.artworkURL = parsedFeed.artworkURL
            updatedPodcast.homePageURL = parsedFeed.homePageURL
            updatedPodcast.lastRefreshDate = Date()
            updatedPodcast.contentHash = contentHash
            updatedPodcast.etag = httpResponse.value(forHTTPHeaderField: "ETag")
            updatedPodcast.lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")
            
            // Update extended metadata
            updatedPodcast.language = parsedFeed.language
            updatedPodcast.showType = parsedFeed.showType
            updatedPodcast.copyright = parsedFeed.copyright
            updatedPodcast.ownerName = parsedFeed.ownerName
            updatedPodcast.ownerEmail = parsedFeed.ownerEmail
            updatedPodcast.explicit = parsedFeed.explicit
            updatedPodcast.subtitle = parsedFeed.subtitle
            updatedPodcast.fundingURL = parsedFeed.fundingURL
            updatedPodcast.htmlDescription = parsedFeed.htmlDescription
            updatedPodcast.categories = parsedFeed.categories
            
            try updatedPodcast.update(db)
            
            // Insert new episodes
            var newCount = 0
            var episodeIds: [Int64] = []
            guard let podcastId = updatedPodcast.id else { return (0, []) }
            
            for parsedEpisode in parsedFeed.episodes {
                // Skip if episode already exists
                if try EpisodeRecord.exists(guid: parsedEpisode.guid, podcastId: podcastId, db: db) {
                    continue
                }
                
                var episode = EpisodeRecord(
                    podcastId: podcastId,
                    guid: parsedEpisode.guid,
                    title: parsedEpisode.title,
                    episodeDescription: parsedEpisode.description,
                    audioURL: parsedEpisode.audioURL,
                    audioMimeType: parsedEpisode.audioMimeType,
                    fileSize: parsedEpisode.fileSize,
                    duration: parsedEpisode.duration,
                    publishedDate: parsedEpisode.publishedDate,
                    imageURL: parsedEpisode.imageURL,
                    episodeNumber: parsedEpisode.episodeNumber,
                    seasonNumber: parsedEpisode.seasonNumber,
                    episodeType: parsedEpisode.episodeType,
                    link: parsedEpisode.link,
                    explicit: parsedEpisode.explicit,
                    subtitle: parsedEpisode.subtitle,
                    author: parsedEpisode.author,
                    contentHTML: parsedEpisode.contentHTML,
                    chaptersURL: parsedEpisode.chaptersURL,
                    transcripts: parsedEpisode.transcripts
                )
                
                try episode.insert(db)
                if let episodeId = episode.id {
                    episodeIds.append(episodeId)
                }
                newCount += 1
            }
            
            return (newCount, episodeIds)
        }
        
        // Queue episodes for AI tagging
        if !newEpisodeIds.isEmpty {
            await EpisodeTagger.shared.queueForTagging(episodeIds: newEpisodeIds)
        }
        
        return newEpisodeCount
    }
    
    /// Subscribe to a new podcast by URL (two-phase: fast initial, then background completion)
    /// - Parameter feedURL: The RSS feed URL
    /// - Returns: The created podcast record (with first 3 episodes)
    func subscribe(to feedURL: String) async throws -> PodcastRecord {
        // Phase 1: Quick subscribe (podcast + first 3 episodes)
        let (podcast, feedData, httpResponse, hasMoreEpisodes) = try await quickSubscribe(to: feedURL)
        
        // Phase 2: Background completion (load remaining episodes if needed)
        if hasMoreEpisodes {
            Task.detached(priority: .utility) { [weak self] in
                guard let self = self else { return }
                await self.completeSubscription(
                    podcast: podcast,
                    feedData: feedData,
                    httpResponse: httpResponse
                )
            }
        }
        
        return podcast
    }
    
    /// Phase 1: Quick subscribe with first 3 episodes
    private func quickSubscribe(to feedURL: String) async throws -> (PodcastRecord, Data, HTTPURLResponse, Bool) {
        guard let url = URL(string: feedURL) else {
            throw FeedParserError.invalidData
        }
        
        // Check if already subscribed
        let exists = try await database.readAsync { db in
            try PodcastRecord.exists(feedURL: feedURL, db: db)
        }
        
        if exists {
            throw SubscriptionError.alreadySubscribed
        }
        
        // Fetch feed
        var request = URLRequest(url: url)
        request.setValue("Outcast/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FeedParserError.networkError(URLError(.badServerResponse))
        }
        
        // Parse with limit of 3 episodes
        let parser = FeedParser()
        let parseResult = try parser.parse(data: data, maxEpisodes: 3)
        let parsedFeed = parseResult.podcast
        
        // Create podcast with first 3 episodes
        let (podcast, episodeIds) = try await database.writeAsync { db -> (PodcastRecord, [Int64]) in
            var podcast = PodcastRecord(
                feedURL: feedURL,
                title: parsedFeed.title,
                author: parsedFeed.author,
                podcastDescription: parsedFeed.description,
                artworkURL: parsedFeed.artworkURL,
                homePageURL: parsedFeed.homePageURL,
                lastRefreshDate: Date(),
                contentHash: data.md5Hash,
                etag: httpResponse.value(forHTTPHeaderField: "ETag"),
                lastModified: httpResponse.value(forHTTPHeaderField: "Last-Modified"),
                artworkColor: Self.generateRandomColor(),
                isFullyLoaded: !parseResult.hasMoreEpisodes,
                language: parsedFeed.language,
                showType: parsedFeed.showType,
                copyright: parsedFeed.copyright,
                ownerName: parsedFeed.ownerName,
                ownerEmail: parsedFeed.ownerEmail,
                explicit: parsedFeed.explicit,
                subtitle: parsedFeed.subtitle,
                fundingURL: parsedFeed.fundingURL,
                htmlDescription: parsedFeed.htmlDescription,
                categories: parsedFeed.categories
            )
            
            try podcast.insert(db)
            
            guard let podcastId = podcast.id else {
                throw FeedParserError.parsingFailed("Failed to insert podcast")
            }
            
            // Insert first 3 episodes
            var episodeIds: [Int64] = []
            for parsedEpisode in parsedFeed.episodes {
                var episode = EpisodeRecord(
                    podcastId: podcastId,
                    guid: parsedEpisode.guid,
                    title: parsedEpisode.title,
                    episodeDescription: parsedEpisode.description,
                    audioURL: parsedEpisode.audioURL,
                    audioMimeType: parsedEpisode.audioMimeType,
                    fileSize: parsedEpisode.fileSize,
                    duration: parsedEpisode.duration,
                    publishedDate: parsedEpisode.publishedDate,
                    imageURL: parsedEpisode.imageURL,
                    episodeNumber: parsedEpisode.episodeNumber,
                    seasonNumber: parsedEpisode.seasonNumber,
                    episodeType: parsedEpisode.episodeType,
                    link: parsedEpisode.link,
                    explicit: parsedEpisode.explicit,
                    subtitle: parsedEpisode.subtitle,
                    author: parsedEpisode.author,
                    contentHTML: parsedEpisode.contentHTML,
                    chaptersURL: parsedEpisode.chaptersURL,
                    transcripts: parsedEpisode.transcripts
                )
                try episode.insert(db)
                if let episodeId = episode.id {
                    episodeIds.append(episodeId)
                }
            }
            
            return (podcast, episodeIds)
        }
        
        // Queue episodes for AI tagging
        if !episodeIds.isEmpty {
            await EpisodeTagger.shared.queueForTagging(episodeIds: episodeIds)
        }
        
        return (podcast, data, httpResponse, parseResult.hasMoreEpisodes)
    }
    
    /// Phase 2: Complete subscription by loading remaining episodes in background
    private func completeSubscription(
        podcast: PodcastRecord,
        feedData: Data,
        httpResponse: HTTPURLResponse
    ) async {
        do {
            // Parse full feed
            let parser = FeedParser()
            let parseResult = try parser.parse(data: feedData)
            let parsedFeed = parseResult.podcast
            
            guard let podcastId = podcast.id else { return }
            
            // Get episodes we already inserted (first 3)
            let existingGuids = try await database.readAsync { db in
                try EpisodeRecord.fetchAllForPodcast(podcastId, db: db).map { $0.guid }
            }
            
            // Filter out episodes we already have
            let newEpisodes = parsedFeed.episodes.filter { !existingGuids.contains($0.guid) }
            
            // Insert remaining episodes in batches of 50
            let batchSize = 50
            for batchStart in stride(from: 0, to: newEpisodes.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, newEpisodes.count)
                let batch = Array(newEpisodes[batchStart..<batchEnd])
                
                let batchEpisodeIds = try await database.writeAsync { db -> [Int64] in
                    var episodeIds: [Int64] = []
                    for parsedEpisode in batch {
                        // Double-check episode doesn't exist (race condition safety)
                        if try EpisodeRecord.exists(guid: parsedEpisode.guid, podcastId: podcastId, db: db) {
                            continue
                        }
                        
                        var episode = EpisodeRecord(
                            podcastId: podcastId,
                            guid: parsedEpisode.guid,
                            title: parsedEpisode.title,
                            episodeDescription: parsedEpisode.description,
                            audioURL: parsedEpisode.audioURL,
                            audioMimeType: parsedEpisode.audioMimeType,
                            fileSize: parsedEpisode.fileSize,
                            duration: parsedEpisode.duration,
                            publishedDate: parsedEpisode.publishedDate,
                            imageURL: parsedEpisode.imageURL,
                            episodeNumber: parsedEpisode.episodeNumber,
                            seasonNumber: parsedEpisode.seasonNumber,
                            episodeType: parsedEpisode.episodeType,
                            link: parsedEpisode.link,
                            explicit: parsedEpisode.explicit,
                            subtitle: parsedEpisode.subtitle,
                            author: parsedEpisode.author,
                            contentHTML: parsedEpisode.contentHTML,
                            chaptersURL: parsedEpisode.chaptersURL,
                            transcripts: parsedEpisode.transcripts
                        )
                        try episode.insert(db)
                        if let episodeId = episode.id {
                            episodeIds.append(episodeId)
                        }
                    }
                    return episodeIds
                }
                
                // Queue episodes for AI tagging
                if !batchEpisodeIds.isEmpty {
                    await EpisodeTagger.shared.queueForTagging(episodeIds: batchEpisodeIds)
                }
            }
            
            // Mark podcast as fully loaded
            try await database.writeAsync { db in
                var updatedPodcast = podcast
                updatedPodcast.isFullyLoaded = true
                try updatedPodcast.update(db)
            }
            
            print("✓ Background loading complete for \(podcast.title): \(newEpisodes.count) additional episodes")
        } catch {
            print("Background loading failed for \(podcast.title): \(error)")
        }
    }
    
    /// Refresh a podcast imported from OPML (two-phase: fast initial, then background completion)
    /// - Parameter podcast: The podcast record to refresh
    /// - Returns: Number of initial episodes loaded (first 3)
    func refreshForImport(podcast: PodcastRecord) async throws -> Int {
        // Phase 1: Quick refresh with first 3 episodes
        let (updatedPodcast, feedData, httpResponse, hasMoreEpisodes) = try await quickRefresh(podcast: podcast)
        
        // Phase 2: Background completion (load remaining episodes if needed)
        if hasMoreEpisodes {
            Task.detached(priority: .background) { [weak self] in
                guard let self = self else { return }
                await self.completeRefresh(
                    podcast: updatedPodcast,
                    feedData: feedData,
                    httpResponse: httpResponse
                )
            }
        }
        
        // Return count of initial episodes loaded
        return try await database.readAsync { db in
            guard let podcastId = updatedPodcast.id else { return 0 }
            return try EpisodeRecord.fetchAllForPodcast(podcastId, db: db).count
        }
    }
    
    /// Phase 1: Quick refresh with first 3 episodes for imported podcast
    private func quickRefresh(podcast: PodcastRecord) async throws -> (PodcastRecord, Data, HTTPURLResponse, Bool) {
        guard let url = URL(string: podcast.feedURL) else {
            throw FeedParserError.invalidData
        }
        
        // Fetch feed
        var request = URLRequest(url: url)
        request.setValue("Outcast/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FeedParserError.networkError(URLError(.badServerResponse))
        }
        
        // Parse with limit of 3 episodes
        let parser = FeedParser()
        let parseResult = try parser.parse(data: data, maxEpisodes: 3)
        let parsedFeed = parseResult.podcast
        
        // Update podcast and insert first 3 episodes
        let (updatedPodcast, episodeIds) = try await database.writeAsync { db -> (PodcastRecord, [Int64]) in
            var podcast = podcast
            podcast.title = parsedFeed.title
            podcast.author = parsedFeed.author
            podcast.podcastDescription = parsedFeed.description
            podcast.artworkURL = parsedFeed.artworkURL
            podcast.homePageURL = parsedFeed.homePageURL
            podcast.lastRefreshDate = Date()
            podcast.contentHash = data.md5Hash
            podcast.etag = httpResponse.value(forHTTPHeaderField: "ETag")
            podcast.lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified")
            podcast.isFullyLoaded = !parseResult.hasMoreEpisodes
            
            // Update extended metadata
            podcast.language = parsedFeed.language
            podcast.showType = parsedFeed.showType
            podcast.copyright = parsedFeed.copyright
            podcast.ownerName = parsedFeed.ownerName
            podcast.ownerEmail = parsedFeed.ownerEmail
            podcast.explicit = parsedFeed.explicit
            podcast.subtitle = parsedFeed.subtitle
            podcast.fundingURL = parsedFeed.fundingURL
            podcast.htmlDescription = parsedFeed.htmlDescription
            podcast.categories = parsedFeed.categories
            
            try podcast.update(db)
            
            guard let podcastId = podcast.id else {
                throw FeedParserError.parsingFailed("Failed to get podcast ID")
            }
            
            // Insert first 3 episodes
            var episodeIds: [Int64] = []
            for parsedEpisode in parsedFeed.episodes {
                // Skip if episode already exists
                if try EpisodeRecord.exists(guid: parsedEpisode.guid, podcastId: podcastId, db: db) {
                    continue
                }
                
                var episode = EpisodeRecord(
                    podcastId: podcastId,
                    guid: parsedEpisode.guid,
                    title: parsedEpisode.title,
                    episodeDescription: parsedEpisode.description,
                    audioURL: parsedEpisode.audioURL,
                    audioMimeType: parsedEpisode.audioMimeType,
                    fileSize: parsedEpisode.fileSize,
                    duration: parsedEpisode.duration,
                    publishedDate: parsedEpisode.publishedDate,
                    imageURL: parsedEpisode.imageURL,
                    episodeNumber: parsedEpisode.episodeNumber,
                    seasonNumber: parsedEpisode.seasonNumber,
                    episodeType: parsedEpisode.episodeType,
                    link: parsedEpisode.link,
                    explicit: parsedEpisode.explicit,
                    subtitle: parsedEpisode.subtitle,
                    author: parsedEpisode.author,
                    contentHTML: parsedEpisode.contentHTML,
                    chaptersURL: parsedEpisode.chaptersURL,
                    transcripts: parsedEpisode.transcripts
                )
                try episode.insert(db)
                if let episodeId = episode.id {
                    episodeIds.append(episodeId)
                }
            }
            
            return (podcast, episodeIds)
        }
        
        // Queue episodes for AI tagging
        if !episodeIds.isEmpty {
            await EpisodeTagger.shared.queueForTagging(episodeIds: episodeIds)
        }
        
        return (updatedPodcast, data, httpResponse, parseResult.hasMoreEpisodes)
    }
    
    /// Phase 2: Complete refresh by loading remaining episodes in background
    private func completeRefresh(
        podcast: PodcastRecord,
        feedData: Data,
        httpResponse: HTTPURLResponse
    ) async {
        do {
            // Parse full feed
            let parser = FeedParser()
            let parseResult = try parser.parse(data: feedData)
            let parsedFeed = parseResult.podcast
            
            guard let podcastId = podcast.id else { return }
            
            // Get episodes we already inserted (first 3)
            let existingGuids = try await database.readAsync { db in
                try EpisodeRecord.fetchAllForPodcast(podcastId, db: db).map { $0.guid }
            }
            
            // Filter out episodes we already have
            let newEpisodes = parsedFeed.episodes.filter { !existingGuids.contains($0.guid) }
            
            // Insert remaining episodes in batches of 50
            let batchSize = 50
            for batchStart in stride(from: 0, to: newEpisodes.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, newEpisodes.count)
                let batch = Array(newEpisodes[batchStart..<batchEnd])
                
                let batchEpisodeIds = try await database.writeAsync { db -> [Int64] in
                    var episodeIds: [Int64] = []
                    for parsedEpisode in batch {
                        // Double-check episode doesn't exist (race condition safety)
                        if try EpisodeRecord.exists(guid: parsedEpisode.guid, podcastId: podcastId, db: db) {
                            continue
                        }
                        
                        var episode = EpisodeRecord(
                            podcastId: podcastId,
                            guid: parsedEpisode.guid,
                            title: parsedEpisode.title,
                            episodeDescription: parsedEpisode.description,
                            audioURL: parsedEpisode.audioURL,
                            audioMimeType: parsedEpisode.audioMimeType,
                            fileSize: parsedEpisode.fileSize,
                            duration: parsedEpisode.duration,
                            publishedDate: parsedEpisode.publishedDate,
                            imageURL: parsedEpisode.imageURL,
                            episodeNumber: parsedEpisode.episodeNumber,
                            seasonNumber: parsedEpisode.seasonNumber,
                            episodeType: parsedEpisode.episodeType,
                            link: parsedEpisode.link,
                            explicit: parsedEpisode.explicit,
                            subtitle: parsedEpisode.subtitle,
                            author: parsedEpisode.author,
                            contentHTML: parsedEpisode.contentHTML,
                            chaptersURL: parsedEpisode.chaptersURL,
                            transcripts: parsedEpisode.transcripts
                        )
                        try episode.insert(db)
                        if let episodeId = episode.id {
                            episodeIds.append(episodeId)
                        }
                    }
                    return episodeIds
                }
                
                // Queue episodes for AI tagging
                if !batchEpisodeIds.isEmpty {
                    await EpisodeTagger.shared.queueForTagging(episodeIds: batchEpisodeIds)
                }
            }
            
            // Mark podcast as fully loaded
            try await database.writeAsync { db in
                var updatedPodcast = podcast
                updatedPodcast.isFullyLoaded = true
                try updatedPodcast.update(db)
            }
            
            print("✓ Background refresh complete for \(podcast.title): \(newEpisodes.count) additional episodes")
        } catch {
            print("Background refresh failed for \(podcast.title): \(error)")
        }
    }
    
    private static func generateRandomColor() -> String {
        let colors = [
            "#FF6B35", "#4ECDC4", "#95E1D3", "#F38181", "#AA96DA",
            "#FCBAD3", "#A8D8EA", "#FFFFD2", "#E84A5F", "#FF847C",
            "#99B898", "#FECEA8", "#2A363B", "#547980", "#45ADA8"
        ]
        return colors.randomElement() ?? "#4ECDC4"
    }
}

// MARK: - Subscription Errors

enum SubscriptionError: Error, LocalizedError {
    case alreadySubscribed
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .alreadySubscribed:
            return "You are already subscribed to this podcast"
        case .invalidURL:
            return "The provided URL is not valid"
        }
    }
}

// MARK: - Data MD5 Hash

extension Data {
    nonisolated var md5Hash: String {
        // Simple hash for content comparison
        // Using a basic hash since we don't need cryptographic security
        let bytes = [UInt8](self)
        var hash: UInt64 = 5381
        for byte in bytes {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(format: "%016llx", hash)
    }
}

// MARK: - UserDefaults for Last Refresh Tracking

extension UserDefaults {
    private static let lastFeedRefreshKey = "lastFeedRefresh"
    
    static var lastFeedRefresh: Date? {
        get { standard.object(forKey: lastFeedRefreshKey) as? Date }
        set { standard.set(newValue, forKey: lastFeedRefreshKey) }
    }
}
