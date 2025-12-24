//
//  OPMLParserTests.swift
//  OutcastTests
//
//  Tests for OPML import parsing
//

import Testing
import Foundation
@testable import Outcast

struct OPMLParserTests {
    
    @Test func parsesBasicOPML() throws {
        let opmlData = TestFixtures.loadFixture("subscriptions", extension: "opml")
        let parser = OPMLParser()
        
        let document = try parser.parse(data: opmlData)
        
        #expect(document.title == "My Podcasts")
        #expect(document.feeds.count == 2)
        
        let techPodcast = document.feeds.first { $0.title == "Tech Podcast" }
        #expect(techPodcast?.feedURL == "https://example.com/tech.xml")
        #expect(techPodcast?.homePageURL == "https://example.com/tech")
        
        let newsDaily = document.feeds.first { $0.title == "News Daily" }
        #expect(newsDaily?.feedURL == "https://example.com/news.xml")
        #expect(newsDaily?.homePageURL == nil)
    }
    
    @Test func handlesNestedOutlines() throws {
        let nestedOPML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <head><title>Organized Podcasts</title></head>
          <body>
            <outline text="Technology">
              <outline text="Dev Podcast" xmlUrl="https://example.com/dev.xml"/>
              <outline text="AI Podcast" xmlUrl="https://example.com/ai.xml"/>
            </outline>
            <outline text="News Podcast" xmlUrl="https://example.com/news.xml"/>
          </body>
        </opml>
        """.data(using: .utf8)!
        
        let parser = OPMLParser()
        let document = try parser.parse(data: nestedOPML)
        
        // Should extract all feeds, even nested ones
        #expect(document.feeds.count == 3)
        
        let feedURLs = document.feeds.map { $0.feedURL }
        #expect(feedURLs.contains("https://example.com/dev.xml"))
        #expect(feedURLs.contains("https://example.com/ai.xml"))
        #expect(feedURLs.contains("https://example.com/news.xml"))
    }
    
    @Test func throwsOnNoFeeds() throws {
        let emptyOPML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <head><title>Empty</title></head>
          <body>
          </body>
        </opml>
        """.data(using: .utf8)!
        
        let parser = OPMLParser()
        
        #expect(throws: OPMLParserError.noFeedsFound) {
            try parser.parse(data: emptyOPML)
        }
    }
    
    @Test func extractsDocumentTitle() throws {
        let opmlData = TestFixtures.loadFixture("subscriptions", extension: "opml")
        let parser = OPMLParser()
        
        let document = try parser.parse(data: opmlData)
        
        #expect(document.title == "My Podcasts")
    }
    
    @Test func handlesAlternateAttributes() throws {
        // Test case-insensitive attribute handling
        let alternateOPML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <body>
            <outline text="Podcast 1" xmlurl="https://example.com/p1.xml" htmlurl="https://example.com/p1"/>
            <outline title="Podcast 2" xmlUrl="https://example.com/p2.xml" htmlUrl="https://example.com/p2"/>
          </body>
        </opml>
        """.data(using: .utf8)!
        
        let parser = OPMLParser()
        let document = try parser.parse(data: alternateOPML)
        
        #expect(document.feeds.count == 2)
        
        // Both lowercase and camelCase should work
        let p1 = document.feeds.first { $0.feedURL == "https://example.com/p1.xml" }
        #expect(p1 != nil)
        #expect(p1?.homePageURL == "https://example.com/p1")
        
        let p2 = document.feeds.first { $0.feedURL == "https://example.com/p2.xml" }
        #expect(p2 != nil)
        #expect(p2?.title == "Podcast 2")
    }
}
