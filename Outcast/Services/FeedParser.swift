//
//  FeedParser.swift
//  Outcast
//
//  Lightweight RSS/Atom feed parser for podcasts
//  Inspired by NetNewsWire's RSParser (MIT License)
//

import Foundation
import UIKit

/// Represents a parsed podcast feed
struct ParsedPodcast: Sendable {
    let title: String
    let author: String?
    let description: String?
    let artworkURL: String?
    let homePageURL: String?
    let episodes: [ParsedEpisode]
}

/// Represents a parsed podcast episode
struct ParsedEpisode: Sendable {
    let guid: String
    let title: String
    let description: String?
    let audioURL: String
    let audioMimeType: String?
    let fileSize: Int64?
    let duration: TimeInterval?
    let publishedDate: Date?
    let imageURL: String?
    let episodeNumber: Int?
    let seasonNumber: Int?
    let episodeType: String?
}

/// Errors that can occur during feed parsing
enum FeedParserError: Error, LocalizedError {
    case invalidData
    case notAFeed
    case noEpisodes
    case networkError(Error)
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The feed contains invalid data"
        case .notAFeed:
            return "The URL does not point to a valid podcast feed"
        case .noEpisodes:
            return "No episodes found in the feed"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingFailed(let message):
            return "Failed to parse feed: \(message)"
        }
    }
}

/// Parser for RSS/Atom podcast feeds
final class FeedParser: @unchecked Sendable {
    
    nonisolated init() {}
    
    /// Parse feed data
    /// - Parameter data: The RSS/Atom feed data
    /// - Returns: A ParsedPodcast with all episodes
    nonisolated func parse(data: Data) throws -> ParsedPodcast {
        // Create a delegate handler that does all the parsing work
        let handler = XMLParserDelegateHandler()
        
        let parser = XMLParser(data: data)
        parser.delegate = handler
        
        guard parser.parse() else {
            if let error = handler.parsingError {
                throw error
            }
            throw FeedParserError.parsingFailed(parser.parserError?.localizedDescription ?? "Unknown error")
        }
        
        guard let title = handler.feedTitle, !title.isEmpty else {
            throw FeedParserError.notAFeed
        }
        
        return ParsedPodcast(
            title: title,
            author: handler.feedAuthor,
            description: handler.feedDescription,
            artworkURL: handler.feedArtworkURL,
            homePageURL: handler.feedHomePageURL,
            episodes: handler.episodes
        )
    }
}

// MARK: - XMLParserDelegateHandler

/// Private helper class that handles XML parsing state and delegates
private final class XMLParserDelegateHandler: NSObject, XMLParserDelegate, @unchecked Sendable {
    
    // Feed-level properties
    nonisolated(unsafe) var feedTitle: String?
    nonisolated(unsafe) var feedAuthor: String?
    nonisolated(unsafe) var feedDescription: String?
    nonisolated(unsafe) var feedArtworkURL: String?
    nonisolated(unsafe) var feedHomePageURL: String?
    
    // Episode collection
    nonisolated(unsafe) var episodes: [ParsedEpisode] = []
    
    // Current parsing state
    nonisolated(unsafe) var currentElement = ""
    nonisolated(unsafe) var currentText = ""
    nonisolated(unsafe) var parsingError: Error?
    
    // Episode being built
    nonisolated(unsafe) var isParsingItem = false
    nonisolated(unsafe) var itemGuid: String?
    nonisolated(unsafe) var itemTitle: String?
    nonisolated(unsafe) var itemDescription: String?
    nonisolated(unsafe) var itemAudioURL: String?
    nonisolated(unsafe) var itemAudioMimeType: String?
    nonisolated(unsafe) var itemFileSize: Int64?
    nonisolated(unsafe) var itemDuration: TimeInterval?
    nonisolated(unsafe) var itemPublishedDate: Date?
    nonisolated(unsafe) var itemImageURL: String?
    nonisolated(unsafe) var itemEpisodeNumber: Int?
    nonisolated(unsafe) var itemSeasonNumber: Int?
    nonisolated(unsafe) var itemEpisodeType: String?
    
    // Date formatters for RSS dates
    nonisolated private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }
    }()
    
    nonisolated override init() {
        super.init()
    }
    
    nonisolated private func resetItemState() {
        isParsingItem = false
        itemGuid = nil
        itemTitle = nil
        itemDescription = nil
        itemAudioURL = nil
        itemAudioMimeType = nil
        itemFileSize = nil
        itemDuration = nil
        itemPublishedDate = nil
        itemImageURL = nil
        itemEpisodeNumber = nil
        itemSeasonNumber = nil
        itemEpisodeType = nil
    }
    
    // MARK: - XMLParserDelegate
    
    nonisolated func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName.lowercased()
        currentText = ""
        
        switch currentElement {
        case "item", "entry":
            isParsingItem = true
            resetItemState()
            isParsingItem = true
            
        case "enclosure":
            // Podcast audio file
            if isParsingItem {
                if let url = attributeDict["url"], !url.isEmpty {
                    itemAudioURL = url
                    itemAudioMimeType = attributeDict["type"]
                    if let length = attributeDict["length"], let size = Int64(length) {
                        itemFileSize = size
                    }
                }
            }
            
        case "itunes:image":
            if let href = attributeDict["href"], !href.isEmpty {
                if isParsingItem {
                    itemImageURL = href
                } else {
                    feedArtworkURL = href
                }
            }
            
        case "media:content", "media:thumbnail":
            // Alternative way to specify media
            if isParsingItem && itemAudioURL == nil {
                if let url = attributeDict["url"],
                   let type = attributeDict["type"],
                   type.hasPrefix("audio/") {
                    itemAudioURL = url
                    itemAudioMimeType = type
                }
            }
            
        default:
            break
        }
    }
    
    nonisolated func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    nonisolated func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let element = elementName.lowercased()
        
        if isParsingItem {
            // Parsing episode
            switch element {
            case "item", "entry":
                // Finish parsing this episode
                if let audioURL = itemAudioURL, !audioURL.isEmpty {
                    let episode = ParsedEpisode(
                        guid: itemGuid ?? audioURL, // Use audio URL as fallback GUID
                        title: itemTitle ?? "Untitled Episode",
                        description: itemDescription,
                        audioURL: audioURL,
                        audioMimeType: itemAudioMimeType,
                        fileSize: itemFileSize,
                        duration: itemDuration,
                        publishedDate: itemPublishedDate,
                        imageURL: itemImageURL,
                        episodeNumber: itemEpisodeNumber,
                        seasonNumber: itemSeasonNumber,
                        episodeType: itemEpisodeType
                    )
                    episodes.append(episode)
                }
                isParsingItem = false
                
            case "guid", "id":
                itemGuid = text
                
            case "title":
                if itemTitle == nil {
                    itemTitle = text
                }
                
            case "description", "content", "content:encoded", "summary":
                if itemDescription == nil || text.count > (itemDescription?.count ?? 0) {
                    itemDescription = text.strippingHTML()
                }
                
            case "pubdate", "published", "dc:date":
                itemPublishedDate = Self.parseDate(text)
                
            case "itunes:duration":
                itemDuration = Self.parseDuration(text)
                
            case "itunes:episode":
                itemEpisodeNumber = Int(text)
                
            case "itunes:season":
                itemSeasonNumber = Int(text)
                
            case "itunes:episodetype":
                itemEpisodeType = text
                
            default:
                break
            }
        } else {
            // Parsing feed-level data
            switch element {
            case "title":
                if feedTitle == nil {
                    feedTitle = text
                }
                
            case "itunes:author", "author", "dc:creator":
                if feedAuthor == nil {
                    feedAuthor = text
                }
                
            case "description", "subtitle", "itunes:summary":
                if feedDescription == nil || text.count > (feedDescription?.count ?? 0) {
                    feedDescription = text.strippingHTML()
                }
                
            case "link":
                if feedHomePageURL == nil && !text.isEmpty {
                    feedHomePageURL = text
                }
                
            default:
                break
            }
        }
        
        currentElement = ""
        currentText = ""
    }
    
    nonisolated func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parsingError = FeedParserError.parsingFailed(parseError.localizedDescription)
    }
    
    // MARK: - Helpers
    
    nonisolated private static func parseDate(_ string: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
    
    nonisolated private static func parseDuration(_ string: String) -> TimeInterval? {
        // Handle HH:MM:SS, MM:SS, or just seconds
        let components = string.split(separator: ":")
        
        switch components.count {
        case 1:
            // Just seconds
            return TimeInterval(string)
            
        case 2:
            // MM:SS
            guard let minutes = Int(components[0]),
                  let seconds = Int(components[1]) else { return nil }
            return TimeInterval(minutes * 60 + seconds)
            
        case 3:
            // HH:MM:SS
            guard let hours = Int(components[0]),
                  let minutes = Int(components[1]),
                  let seconds = Int(components[2]) else { return nil }
            return TimeInterval(hours * 3600 + minutes * 60 + seconds)
            
        default:
            return nil
        }
    }
}

// MARK: - String HTML Stripping

private extension String {
    nonisolated func strippingHTML() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributed.string
        }
        
        // Fallback: simple regex-based stripping
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
