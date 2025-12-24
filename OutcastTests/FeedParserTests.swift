//
//  FeedParserTests.swift
//  OutcastTests
//
//  Tests for RSS/Atom feed parsing
//

import Testing
import Foundation
@testable import Outcast

struct FeedParserTests {
    
    // MARK: - Basic Parsing
    
    @Test func parsesBasicRSSFeed() throws {
        let feedData = TestFixtures.loadFixture("basic-feed", extension: "xml")
        let parser = FeedParser()
        
        let result = try parser.parse(data: feedData)
        
        #expect(result.podcast.title == "Test Podcast")
        #expect(result.podcast.author == "Test Author")
        #expect(result.podcast.description == "A test podcast description")
        #expect(result.podcast.episodes.count == 1)
        #expect(result.hasMoreEpisodes == false)
        
        let episode = result.podcast.episodes[0]
        #expect(episode.title == "Episode 1")
        #expect(episode.guid == "ep-001")
        #expect(episode.audioURL == "https://example.com/ep1.mp3")
        #expect(episode.audioMimeType == "audio/mpeg")
        #expect(episode.fileSize == 12345)
    }
    
    @Test func parsesDurationFormats() throws {
        let feedData = TestFixtures.loadFixture("edge-cases-feed", extension: "xml")
        let parser = FeedParser()
        
        let result = try parser.parse(data: feedData)
        let episodes = result.podcast.episodes
        
        // Find episodes by title
        let secondsEp = episodes.first { $0.title == "Duration in Seconds" }
        let mmssEp = episodes.first { $0.title == "Duration MM:SS" }
        
        // Duration in seconds: 3600
        #expect(secondsEp?.duration == 3600.0)
        
        // Duration in MM:SS: 45:30 = 2730 seconds
        #expect(mmssEp?.duration == 2730.0)
    }
    
    @Test func parsesDateFormats() throws {
        let feedData = TestFixtures.loadFixture("basic-feed", extension: "xml")
        let parser = FeedParser()
        
        let result = try parser.parse(data: feedData)
        let episode = result.podcast.episodes[0]
        
        // Verify date was parsed (Mon, 01 Jan 2024 12:00:00 +0000)
        #expect(episode.publishedDate != nil)
        
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: episode.publishedDate!)
        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }
    
    @Test func handlesHTTPtoHTTPS() throws {
        let feedData = TestFixtures.loadFixture("complex-feed", extension: "xml")
        let parser = FeedParser()
        
        let result = try parser.parse(data: feedData)
        let episode = result.podcast.episodes[0]
        
        // Feed has http://example.com/complex1.mp3, should be upgraded to https://
        #expect(episode.audioURL.hasPrefix("https://"))
        #expect(episode.audioURL == "https://example.com/complex1.mp3")
    }
    
    @Test func stripsHTMLFromDescription() throws {
        let feedData = TestFixtures.loadFixture("edge-cases-feed", extension: "xml")
        let parser = FeedParser()
        
        let result = try parser.parse(data: feedData)
        let htmlEpisode = result.podcast.episodes.first { $0.title == "HTML Description" }
        
        // HTML tags should be stripped
        #expect(htmlEpisode?.description?.contains("<p>") == false)
        #expect(htmlEpisode?.description?.contains("<strong>") == false)
        #expect(htmlEpisode?.description?.contains("HTML") == true)
    }
    
    @Test func handlesMissingOptionalFields() throws {
        let feedData = TestFixtures.loadFixture("edge-cases-feed", extension: "xml")
        let parser = FeedParser()
        
        let result = try parser.parse(data: feedData)
        let minimalEpisode = result.podcast.episodes.first { $0.title == "Minimal Episode" }
        
        // Should parse successfully even with minimal fields
        #expect(minimalEpisode != nil)
        #expect(minimalEpisode?.guid == "minimal-001")
        #expect(minimalEpisode?.audioURL == "https://example.com/minimal.mp3")
        
        // Optional fields should be nil
        #expect(minimalEpisode?.duration == nil)
        #expect(minimalEpisode?.publishedDate == nil)
        #expect(minimalEpisode?.fileSize == nil)
    }
    
    @Test func respectsMaxEpisodesLimit() throws {
        let feedData = TestFixtures.loadFixture("edge-cases-feed", extension: "xml")
        let parser = FeedParser()
        
        // Feed has 4 episodes, limit to 2
        let result = try parser.parse(data: feedData, maxEpisodes: 2)
        
        #expect(result.podcast.episodes.count == 2)
        #expect(result.hasMoreEpisodes == true)
    }
    
    @Test func parsesExtendedMetadata() throws {
        let feedData = TestFixtures.loadFixture("complex-feed", extension: "xml")
        let parser = FeedParser()
        
        let result = try parser.parse(data: feedData)
        
        // Podcast-level metadata
        #expect(result.podcast.language == "en-US")
        #expect(result.podcast.showType == "episodic")
        #expect(result.podcast.copyright == "© 2024 Test Corp")
        #expect(result.podcast.ownerName == "Owner Name")
        #expect(result.podcast.ownerEmail == "owner@example.com")
        #expect(result.podcast.explicit == false)
        #expect(result.podcast.subtitle == "Test subtitle")
        #expect(result.podcast.fundingURL == "https://example.com/support")
        #expect(result.podcast.htmlDescription?.contains("<p>Rich HTML description</p>") == true)
        #expect(result.podcast.categories != nil)
        
        // Episode-level metadata
        let episode = result.podcast.episodes[0]
        #expect(episode.episodeNumber == 42)
        #expect(episode.seasonNumber == 2)
        #expect(episode.episodeType == "full")
        #expect(episode.explicit == true)
        #expect(episode.subtitle == "Episode subtitle")
        #expect(episode.author == "Guest Author")
        #expect(episode.link == "https://example.com/episode/42")
        #expect(episode.contentHTML?.contains("<strong>HTML</strong>") == true)
        #expect(episode.chaptersURL == "https://example.com/chapters.json")
        #expect(episode.transcripts != nil)
    }
    
    @Test func throwsOnInvalidData() throws {
        let invalidData = "not xml at all".data(using: .utf8)!
        let parser = FeedParser()
        
        #expect(throws: FeedParserError.self) {
            try parser.parse(data: invalidData)
        }
    }
}
