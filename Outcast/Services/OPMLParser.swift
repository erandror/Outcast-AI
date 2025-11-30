//
//  OPMLParser.swift
//  Outcast
//
//  Lightweight OPML parser for importing podcast subscriptions
//  Inspired by NetNewsWire's RSOPMLParser (MIT License)
//

import Foundation
import GRDB

/// Represents a feed from an OPML file
struct OPMLFeed: Sendable {
    let title: String?
    let feedURL: String
    let homePageURL: String?
}

/// Represents the result of parsing an OPML file
struct OPMLDocument: Sendable {
    let title: String?
    let feeds: [OPMLFeed]
}

/// Errors that can occur during OPML parsing
enum OPMLParserError: Error, LocalizedError {
    case invalidData
    case parsingFailed(String)
    case noFeedsFound
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The OPML file contains invalid data"
        case .parsingFailed(let message):
            return "Failed to parse OPML: \(message)"
        case .noFeedsFound:
            return "No podcast feeds found in the OPML file"
        }
    }
}

/// Parser for OPML files containing podcast subscriptions
final class OPMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    
    private var feeds: [OPMLFeed] = []
    private var documentTitle: String?
    private var parsingError: Error?
    private var isInHead = false
    
    /// Parse OPML data and return the feeds
    /// - Parameter data: The OPML file data
    /// - Returns: An OPMLDocument containing the parsed feeds
    func parse(data: Data) throws -> OPMLDocument {
        feeds = []
        documentTitle = nil
        parsingError = nil
        isInHead = false
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        guard parser.parse() else {
            if let error = parsingError {
                throw error
            }
            throw OPMLParserError.parsingFailed(parser.parserError?.localizedDescription ?? "Unknown error")
        }
        
        if feeds.isEmpty {
            throw OPMLParserError.noFeedsFound
        }
        
        return OPMLDocument(title: documentTitle, feeds: feeds)
    }
    
    /// Parse OPML from a file URL
    /// - Parameter url: The URL of the OPML file
    /// - Returns: An OPMLDocument containing the parsed feeds
    func parse(contentsOf url: URL) throws -> OPMLDocument {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName.lowercased() {
        case "head":
            isInHead = true
            
        case "title" where isInHead:
            // Will capture title in foundCharacters
            break
            
        case "outline":
            // Check if this is a feed (has xmlUrl attribute)
            if let feedURL = attributeDict["xmlUrl"] ?? attributeDict["xmlurl"] {
                let trimmedURL = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedURL.isEmpty else { return }
                
                let title = attributeDict["text"] ?? attributeDict["title"]
                let homePageURL = attributeDict["htmlUrl"] ?? attributeDict["htmlurl"]
                
                let feed = OPMLFeed(
                    title: title,
                    feedURL: trimmedURL,
                    homePageURL: homePageURL
                )
                feeds.append(feed)
            }
            // If no xmlUrl, this might be a folder - we'll still process child outlines
            
        default:
            break
        }
    }
    
    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName.lowercased() == "head" {
            isInHead = false
        }
    }
    
    private var currentText = ""
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInHead {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parsingError = OPMLParserError.parsingFailed(parseError.localizedDescription)
    }
}

// MARK: - Convenience Extensions

extension OPMLParser {
    
    /// Parse OPML and import feeds into the database
    /// Returns immediately after creating podcast records; episodes are synced in background
    static func importOPML(from url: URL, database: AppDatabase) async throws -> [PodcastRecord] {
        let parser = OPMLParser()
        let document = try parser.parse(contentsOf: url)
        
        // Create podcast records immediately (no refresh yet)
        let importedPodcasts = try await database.writeAsync { db -> [PodcastRecord] in
            var podcasts: [PodcastRecord] = []
            
            for feed in document.feeds {
                // Skip if already subscribed
                if try PodcastRecord.exists(feedURL: feed.feedURL, db: db) {
                    continue
                }
                
                // Create a new podcast record (placeholder, will be enriched during refresh)
                var podcast = PodcastRecord(
                    feedURL: feed.feedURL,
                    title: feed.title ?? "Untitled Podcast",
                    homePageURL: feed.homePageURL,
                    artworkColor: Self.generateRandomColor(),
                    isFullyLoaded: false  // Mark as not fully loaded yet
                )
                
                try podcast.insert(db)
                podcasts.append(podcast)
            }
            
            return podcasts
        }
        
        // Fire off background import (non-blocking)
        if !importedPodcasts.isEmpty {
            Task.detached(priority: .utility) {
                await ImportCoordinator.shared.importPodcasts(importedPodcasts)
            }
        }
        
        return importedPodcasts
    }
    
    /// Generate a random color hex for artwork placeholder
    private static func generateRandomColor() -> String {
        let colors = [
            "#FF6B35", "#4ECDC4", "#95E1D3", "#F38181", "#AA96DA",
            "#FCBAD3", "#A8D8EA", "#FFFFD2", "#E84A5F", "#FF847C",
            "#99B898", "#FECEA8", "#2A363B", "#547980", "#45ADA8"
        ]
        return colors.randomElement() ?? "#4ECDC4"
    }
}
