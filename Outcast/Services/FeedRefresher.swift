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
        
        var totalNewEpisodes = 0
        
        // Refresh feeds concurrently but with a limit
        await withTaskGroup(of: Int.self) { group in
            for podcast in podcasts {
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
        let parsedFeed = try parser.parse(data: data)
        
        // Update podcast and save new episodes
        let newEpisodeCount = try await database.writeAsync { db -> Int in
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
            
            try updatedPodcast.update(db)
            
            // Insert new episodes
            var newCount = 0
            guard let podcastId = updatedPodcast.id else { return 0 }
            
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
                    episodeType: parsedEpisode.episodeType
                )
                
                try episode.insert(db)
                newCount += 1
            }
            
            return newCount
        }
        
        return newEpisodeCount
    }
    
    /// Subscribe to a new podcast by URL
    /// - Parameter feedURL: The RSS feed URL
    /// - Returns: The created podcast record
    func subscribe(to feedURL: String) async throws -> PodcastRecord {
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
        
        // Fetch and parse the feed
        var request = URLRequest(url: url)
        request.setValue("Outcast/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FeedParserError.networkError(URLError(.badServerResponse))
        }
        
        let parser = FeedParser()
        let parsedFeed = try parser.parse(data: data)
        
        // Create podcast and episodes
        let podcast = try await database.writeAsync { db -> PodcastRecord in
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
                artworkColor: Self.generateRandomColor()
            )
            
            try podcast.insert(db)
            
            guard let podcastId = podcast.id else {
                throw FeedParserError.parsingFailed("Failed to insert podcast")
            }
            
            // Insert episodes
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
                    episodeType: parsedEpisode.episodeType
                )
                try episode.insert(db)
            }
            
            return podcast
        }
        
        return podcast
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
