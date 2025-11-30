//
//  FeedParser.swift
//  Outcast
//
//  Lightweight RSS/Atom feed parser for podcasts
//  Inspired by NetNewsWire's RSParser (MIT License)
//

import Foundation
import UIKit

/// Result of parsing a podcast feed
struct ParseResult: Sendable {
    let podcast: ParsedPodcast
    let hasMoreEpisodes: Bool
}

/// Represents a parsed podcast feed
struct ParsedPodcast: Sendable {
    let title: String
    let author: String?
    let description: String?
    let artworkURL: String?
    let homePageURL: String?
    let episodes: [ParsedEpisode]
    
    // Extended metadata
    let language: String?
    let showType: String?
    let copyright: String?
    let ownerName: String?
    let ownerEmail: String?
    let explicit: Bool?
    let subtitle: String?
    let fundingURL: String?
    let htmlDescription: String?
    let categories: String?  // JSON array
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
    
    // Extended metadata
    let link: String?
    let explicit: Bool?
    let subtitle: String?
    let author: String?
    let contentHTML: String?
    let chaptersURL: String?
    let transcripts: String?  // JSON array
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
    
    /// Encode an array of strings to JSON
    nonisolated private static func encodeJSONArray(_ array: [String]) -> String? {
        guard let data = try? JSONEncoder().encode(array),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    /// Encode an array of dictionaries to JSON
    nonisolated private static func encodeJSONObject(_ array: [[String: String]]) -> String? {
        guard let data = try? JSONEncoder().encode(array),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    /// Parse feed data
    /// - Parameters:
    ///   - data: The RSS/Atom feed data
    ///   - maxEpisodes: Optional maximum number of episodes to parse (nil = all)
    /// - Returns: A ParseResult with podcast info and whether more episodes exist
    nonisolated func parse(data: Data, maxEpisodes: Int? = nil) throws -> ParseResult {
        // Create a delegate handler that does all the parsing work
        let handler = XMLParserDelegateHandler(maxEpisodes: maxEpisodes)
        
        let parser = XMLParser(data: data)
        parser.delegate = handler
        
        guard parser.parse() || handler.reachedEpisodeLimit else {
            if let error = handler.parsingError {
                throw error
            }
            throw FeedParserError.parsingFailed(parser.parserError?.localizedDescription ?? "Unknown error")
        }
        
        guard let title = handler.feedTitle, !title.isEmpty else {
            throw FeedParserError.notAFeed
        }
        
        let podcast = ParsedPodcast(
            title: title,
            author: handler.feedAuthor,
            description: handler.feedDescription,
            artworkURL: handler.feedArtworkURL,
            homePageURL: handler.feedHomePageURL,
            episodes: handler.episodes,
            language: handler.feedLanguage,
            showType: handler.feedShowType,
            copyright: handler.feedCopyright,
            ownerName: handler.feedOwnerName,
            ownerEmail: handler.feedOwnerEmail,
            explicit: handler.feedExplicit,
            subtitle: handler.feedSubtitle,
            fundingURL: handler.feedFundingURL,
            htmlDescription: handler.feedHTMLDescription,
            categories: handler.feedCategories.isEmpty ? nil : Self.encodeJSONArray(handler.feedCategories)
        )
        
        return ParseResult(
            podcast: podcast,
            hasMoreEpisodes: handler.reachedEpisodeLimit
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
    nonisolated(unsafe) var feedLanguage: String?
    nonisolated(unsafe) var feedShowType: String?
    nonisolated(unsafe) var feedCopyright: String?
    nonisolated(unsafe) var feedOwnerName: String?
    nonisolated(unsafe) var feedOwnerEmail: String?
    nonisolated(unsafe) var feedExplicit: Bool?
    nonisolated(unsafe) var feedSubtitle: String?
    nonisolated(unsafe) var feedFundingURL: String?
    nonisolated(unsafe) var feedHTMLDescription: String?
    nonisolated(unsafe) var feedCategories: [String] = []
    
    // Episode collection
    nonisolated(unsafe) var episodes: [ParsedEpisode] = []
    
    // Episode limit tracking
    nonisolated(unsafe) var maxEpisodes: Int?
    nonisolated(unsafe) var reachedEpisodeLimit = false
    nonisolated(unsafe) weak var parser: XMLParser?
    
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
    nonisolated(unsafe) var itemLink: String?
    nonisolated(unsafe) var itemExplicit: Bool?
    nonisolated(unsafe) var itemSubtitle: String?
    nonisolated(unsafe) var itemAuthor: String?
    nonisolated(unsafe) var itemContentHTML: String?
    nonisolated(unsafe) var itemChaptersURL: String?
    nonisolated(unsafe) var itemTranscripts: [[String: String]] = []
    
    // Parsing state for owner element
    nonisolated(unsafe) var isParsingOwner = false
    nonisolated(unsafe) var tempOwnerName: String?
    nonisolated(unsafe) var tempOwnerEmail: String?
    
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
    
    nonisolated init(maxEpisodes: Int? = nil) {
        self.maxEpisodes = maxEpisodes
        super.init()
    }
    
    /// Encode an array of dictionaries to JSON
    nonisolated private static func encodeJSONObject(_ array: [[String: String]]) -> String? {
        guard let data = try? JSONEncoder().encode(array),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
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
        itemLink = nil
        itemExplicit = nil
        itemSubtitle = nil
        itemAuthor = nil
        itemContentHTML = nil
        itemChaptersURL = nil
        itemTranscripts = []
    }
    
    // MARK: - XMLParserDelegate
    
    nonisolated func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        // Capture parser reference for early termination
        if self.parser == nil {
            self.parser = parser
        }
        
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
            
        case "itunes:owner":
            isParsingOwner = true
            tempOwnerName = nil
            tempOwnerEmail = nil
            
        case "itunes:category":
            // Build categories array from nested structure
            if let text = attributeDict["text"], !text.isEmpty {
                feedCategories.append(text)
            }
            
        case "podcast:funding":
            if let url = attributeDict["url"], !url.isEmpty, !isParsingItem {
                feedFundingURL = url
            }
            
        case "podcast:transcript":
            if isParsingItem {
                var transcript: [String: String] = [:]
                if let url = attributeDict["url"] {
                    transcript["url"] = url
                }
                if let type = attributeDict["type"] {
                    transcript["type"] = type
                }
                if let language = attributeDict["language"] {
                    transcript["language"] = language
                }
                if !transcript.isEmpty {
                    itemTranscripts.append(transcript)
                }
            }
            
        case "podcast:chapters":
            if isParsingItem, let url = attributeDict["url"], !url.isEmpty {
                itemChaptersURL = url
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
                    let transcriptsJSON = itemTranscripts.isEmpty ? nil : Self.encodeJSONObject(itemTranscripts)
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
                        episodeType: itemEpisodeType,
                        link: itemLink,
                        explicit: itemExplicit,
                        subtitle: itemSubtitle,
                        author: itemAuthor,
                        contentHTML: itemContentHTML,
                        chaptersURL: itemChaptersURL,
                        transcripts: transcriptsJSON
                    )
                    episodes.append(episode)
                    
                    // Check if we've reached the episode limit
                    if let maxEpisodes = maxEpisodes, episodes.count >= maxEpisodes {
                        reachedEpisodeLimit = true
                        self.parser?.abortParsing()
                        return
                    }
                }
                isParsingItem = false
                
            case "guid", "id":
                itemGuid = text
                
            case "title":
                if itemTitle == nil {
                    itemTitle = text
                }
                
            case "description", "summary":
                if itemDescription == nil || text.count > (itemDescription?.count ?? 0) {
                    itemDescription = text.strippingHTML()
                }
                
            case "content:encoded", "content":
                // Preserve HTML in contentHTML, strip for description
                if itemContentHTML == nil || text.count > (itemContentHTML?.count ?? 0) {
                    itemContentHTML = text
                }
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
                
            case "link":
                if itemLink == nil && !text.isEmpty {
                    itemLink = text
                }
                
            case "itunes:explicit":
                itemExplicit = Self.parseExplicit(text)
                
            case "itunes:subtitle":
                if itemSubtitle == nil {
                    itemSubtitle = text
                }
                
            case "itunes:author", "author", "dc:creator":
                // Episode-level author (guest name)
                if itemAuthor == nil {
                    itemAuthor = text
                }
                
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
                
            case "description", "itunes:summary":
                if feedDescription == nil || text.count > (feedDescription?.count ?? 0) {
                    feedDescription = text.strippingHTML()
                }
                
            case "content:encoded":
                // Preserve HTML version separately
                if feedHTMLDescription == nil || text.count > (feedHTMLDescription?.count ?? 0) {
                    feedHTMLDescription = text
                }
                if feedDescription == nil || text.count > (feedDescription?.count ?? 0) {
                    feedDescription = text.strippingHTML()
                }
                
            case "itunes:subtitle":
                if feedSubtitle == nil {
                    feedSubtitle = text
                }
                
            case "link":
                if feedHomePageURL == nil && !text.isEmpty {
                    feedHomePageURL = text
                }
                
            case "language":
                if feedLanguage == nil {
                    feedLanguage = text
                }
                
            case "copyright":
                if feedCopyright == nil {
                    feedCopyright = text
                }
                
            case "itunes:type":
                if feedShowType == nil {
                    feedShowType = text
                }
                
            case "itunes:explicit":
                if feedExplicit == nil {
                    feedExplicit = Self.parseExplicit(text)
                }
                
            case "itunes:keywords":
                // Note: keywords are comma-separated, we're not splitting them
                // Could add logic to parse and store as array if needed
                break
                
            case "itunes:owner":
                // End of owner element, save the collected data
                if tempOwnerName != nil || tempOwnerEmail != nil {
                    feedOwnerName = tempOwnerName
                    feedOwnerEmail = tempOwnerEmail
                }
                isParsingOwner = false
                
            case "itunes:name":
                if isParsingOwner {
                    tempOwnerName = text
                }
                
            case "itunes:email":
                if isParsingOwner {
                    tempOwnerEmail = text
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
    
    nonisolated private static func parseExplicit(_ string: String) -> Bool? {
        let lowercased = string.lowercased()
        switch lowercased {
        case "true", "yes":
            return true
        case "false", "no", "clean":
            return false
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
