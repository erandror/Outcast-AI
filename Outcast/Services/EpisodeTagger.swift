//
//  EpisodeTagger.swift
//  Outcast
//
//  AI-powered episode tagging using Apple's SystemLanguageModel
//  Tags episodes with mood and topic classifications in the background
//

import Foundation
import GRDB

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Result of tagging an episode
struct TaggingResult: Sendable {
    let episodeId: Int64
    let moodTagNames: [String]
    let topicTagNames: [String]
}

/// Guided generation model for episode classification (iOS 26+)
#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "Episode tag classification based on content analysis")
struct TagClassification {
    @Guide(description: "1-3 mood tags matching the episode's tone and energy")
    var mood: [String]
    
    @Guide(description: "1-5 topic tags matching the subject matter")
    var topic: [String]
}
#endif

/// Manages background AI tagging of episodes using SystemLanguageModel
actor EpisodeTagger {
    
    /// Shared instance
    static let shared = EpisodeTagger()
    
    private let database: AppDatabase
    private var isProcessing = false
    private var backgroundTask: Task<Void, Never>?
    
    init(database: AppDatabase = AppDatabase.shared) {
        self.database = database
    }
    
    /// Check if AI tagging is available on this device
    /// This is a quick synchronous check for OS version only
    nonisolated var isOSVersionSupported: Bool {
        if #available(iOS 26.0, macOS 26.0, *) {
            #if canImport(FoundationModels)
            return true
            #else
            return false
            #endif
        }
        return false
    }
    
    /// Check if SystemLanguageModel is actually available (async check)
    @available(iOS 26.0, macOS 26.0, *)
    private func checkModelAvailability() async -> Bool {
        #if canImport(FoundationModels)
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            return true
        case .unavailable:
            print("📝 Apple Intelligence not available on this device")
            return false
        @unknown default:
            print("📝 Unknown model availability status")
            return false
        }
        #else
        return false
        #endif
    }
    
    /// Start the background processing loop
    func startBackgroundProcessing() {
        guard backgroundTask == nil else { return }
        
        // Only start if OS version supports FoundationModels
        guard isOSVersionSupported else {
            print("📝 AI tagging not available on this device (requires iOS 26+)")
            return
        }
        
        backgroundTask = Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            // Process queue every 30 seconds
            while !Task.isCancelled {
                await self.processQueue()
                
                // Wait 30 seconds before next cycle
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        
        print("🤖 Episode AI tagger started")
    }
    
    /// Stop the background processing loop
    func stopBackgroundProcessing() {
        backgroundTask?.cancel()
        backgroundTask = nil
    }
    
    /// Queue episodes for background tagging (called after episode insertion)
    func queueForTagging(episodeIds: [Int64]) async {
        // Episodes are already marked with needsTagging=true by default
        // This function is just a trigger to start processing if needed
        guard !episodeIds.isEmpty else { return }
        
        print("📝 Queued \(episodeIds.count) episode(s) for AI tagging")
        
        // Only process if OS version supports AI
        guard isOSVersionSupported else { return }
        
        // If not already processing, start a processing cycle
        if !isProcessing {
            Task.detached(priority: .utility) { [weak self] in
                await self?.processQueue()
            }
        }
    }
    
    /// Process queued episodes (called periodically or on-demand)
    func processQueue() async {
        guard !isProcessing else { return }
        
        // Check if SystemLanguageModel is available (iOS 26+)
        guard #available(iOS 26.0, macOS 26.0, *) else {
            return
        }
        
        #if canImport(FoundationModels)
        await processQueueWithFoundationModels()
        #endif
    }
    
    /// Process queue using FoundationModels (iOS 26+)
    @available(iOS 26.0, macOS 26.0, *)
    private func processQueueWithFoundationModels() async {
        #if canImport(FoundationModels)
        isProcessing = true
        defer { isProcessing = false }
        
        // Check if model is actually available on this device
        guard await checkModelAvailability() else {
            print("⚠️ SystemLanguageModel not available, skipping tagging queue")
            return
        }
        
        do {
            // Fetch episodes that need tagging (batch of 20)
            let episodes = try await database.readAsync { db in
                try EpisodeRecord.fetchNeedingTagging(limit: 20, db: db)
            }
            
            guard !episodes.isEmpty else {
                return
            }
            
            print("🤖 Processing \(episodes.count) episode(s) for AI tagging...")
            
            // Fetch all system tags once
            let (moodTags, topicTags) = try await database.readAsync { db in
                let mood = try SystemTagRecord.fetchMoodTags(db: db)
                let topic = try SystemTagRecord.fetchTopicTags(db: db)
                return (mood, topic)
            }
            
            // Define session instructions (used for each new session)
            let instructions = """
            You are a podcast episode classifier. Analyze episodes and select appropriate tags from provided lists only.
            For mood: Select 1-3 tags that match the tone, energy, and emotional quality.
            For topic: Select 1-5 tags that match the subject matter and content themes.
            """
            
            // Process each episode
            var successCount = 0
            for episode in episodes {
                // Check for cancellation
                if Task.isCancelled {
                    break
                }
                
                do {
                    // Fetch the podcast for this episode
                    guard let podcast = try await database.readAsync({ db in
                        try PodcastRecord.fetchOne(db, id: episode.podcastId)
                    }) else {
                        print("⚠️ Skipping episode \(episode.id ?? 0): podcast not found")
                        // Mark as complete to avoid retrying
                        try? await markEpisodeTagged(episode)
                        continue
                    }
                    
                    // Create a new session for each episode (avoid context buildup)
                    let session = LanguageModelSession(instructions: instructions)
                    
                    // Classify the episode
                    let result = try await classifyEpisode(
                        session: session,
                        episode: episode,
                        podcast: podcast,
                        moodTags: moodTags,
                        topicTags: topicTags
                    )
                    
                    // Apply tags to episode
                    try await applyTags(result: result)
                    
                    successCount += 1
                    
                    // Small delay to avoid overwhelming the model
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                } catch let error as LanguageModelSession.GenerationError {
                    switch error {
                    case .exceededContextWindowSize:
                        print("⚠️ Episode description too long, skipping: \(episode.id ?? 0)")
                    default:
                        print("⚠️ Generation error for episode \(episode.id ?? 0): \(error)")
                    }
                    // Mark as complete to avoid retrying indefinitely
                    try? await markEpisodeTagged(episode)
                } catch {
                    print("⚠️ Failed to tag episode \(episode.id ?? 0): \(error)")
                    // Mark as complete anyway to avoid retrying indefinitely
                    try? await markEpisodeTagged(episode)
                }
            }
            
            if successCount > 0 {
                print("✅ Successfully tagged \(successCount) episode(s)")
            }
            
        } catch {
            print("❌ Error processing tagging queue: \(error)")
        }
        #endif
    }
    
    /// Classify an episode using FoundationModels LanguageModelSession with guided generation
    @available(iOS 26.0, macOS 26.0, *)
    private func classifyEpisode(
        session: LanguageModelSession,
        episode: EpisodeRecord,
        podcast: PodcastRecord,
        moodTags: [SystemTagRecord],
        topicTags: [SystemTagRecord]
    ) async throws -> TaggingResult {
        #if canImport(FoundationModels)
        // Prepare the prompt
        let moodTagList = moodTags.map { $0.name }.joined(separator: ", ")
        let topicTagList = topicTags.map { $0.name }.joined(separator: ", ")
        
        let episodeDesc = episode.episodeDescription ?? ""
        let podcastCategories = podcast.categories ?? "[]"
        
        let prompt = """
        Analyze this podcast episode and select the most appropriate tags from the provided lists.
        
        Episode Details:
        - Title: \(episode.title)
        - Description: \(String(episodeDesc.prefix(500)))
        - Podcast: \(podcast.title)
        - Podcast Categories: \(podcastCategories)
        
        Available MOOD TAGS (select 1-3 that best match the tone/feeling):
        \(moodTagList)
        
        Available TOPIC TAGS (select 1-5 that best match the subject matter):
        \(topicTagList)
        
        Use only tags from the provided lists. Select mood tags based on the episode's tone, energy, and emotional quality. Select topic tags based on the subject matter and content themes.
        """
        
        // Use guided generation for structured response
        let response = try await session.respond(to: prompt, generating: TagClassification.self)
        let classification = response.content
        
        // Validate tags against available tags
        let validMoodTags = classification.mood.filter { tag in
            moodTags.contains(where: { $0.name.lowercased() == tag.lowercased() })
        }
        
        let validTopicTags = classification.topic.filter { tag in
            topicTags.contains(where: { $0.name.lowercased() == tag.lowercased() })
        }
        
        guard let episodeId = episode.id else {
            throw TaggingError.missingEpisodeId
        }
        
        return TaggingResult(
            episodeId: episodeId,
            moodTagNames: validMoodTags,
            topicTagNames: validTopicTags
        )
        #else
        throw TaggingError.modelUnavailable
        #endif
    }
    
    /// Mark an episode as tagged (helper)
    private func markEpisodeTagged(_ episode: EpisodeRecord) async throws {
        try await database.writeAsync { db in
            var ep = episode
            try ep.markTaggingComplete(db: db)
        }
    }
    
    /// Apply tags to an episode in the database
    private func applyTags(result: TaggingResult) async throws {
        try await database.writeAsync { db in
            // Get the episode
            guard var episode = try EpisodeRecord.fetchOne(db, id: result.episodeId) else {
                return
            }
            
            // Find tag IDs for the mood tags
            var tagIds: [Int64] = []
            
            for tagName in result.moodTagNames {
                if let tag = try SystemTagRecord.fetchByName(tagName, type: .mood, db: db),
                   let tagId = tag.id {
                    tagIds.append(tagId)
                }
            }
            
            // Find tag IDs for the topic tags
            for tagName in result.topicTagNames {
                if let tag = try SystemTagRecord.fetchByName(tagName, type: .topic, db: db),
                   let tagId = tag.id {
                    tagIds.append(tagId)
                }
            }
            
            // Apply tags to episode
            if !tagIds.isEmpty {
                try EpisodeTagRecord.setTags(episodeId: result.episodeId, tagIds: tagIds, db: db)
            }
            
            // Mark episode as tagged
            try episode.markTaggingComplete(db: db)
        }
    }
}

// MARK: - Errors

enum TaggingError: Error, LocalizedError {
    case modelUnavailable
    case invalidResponse
    case missingEpisodeId
    
    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "SystemLanguageModel is not available on this device"
        case .invalidResponse:
            return "Failed to parse AI response"
        case .missingEpisodeId:
            return "Episode ID is missing"
        }
    }
}

