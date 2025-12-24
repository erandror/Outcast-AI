//
//  ModelTests.swift
//  OutcastTests
//
//  Tests for model computed properties and enum behavior
//

import Testing
import Foundation
@testable import Outcast

struct ModelTests {
    
    // MARK: - Duration Formatting Tests
    
    @Test func formatsDurationInMinutes() {
        let episode = EpisodeRecord(
            podcastId: 1,
            guid: "test",
            title: "Test",
            audioURL: "https://example.com/test.mp3",
            duration: 1800 // 30 minutes
        )
        
        #expect(episode.durationFormatted == "30m")
    }
    
    @Test func formatsDurationInHoursAndMinutes() {
        let episode = EpisodeRecord(
            podcastId: 1,
            guid: "test",
            title: "Test",
            audioURL: "https://example.com/test.mp3",
            duration: 5430 // 1 hour 30 minutes 30 seconds
        )
        
        #expect(episode.durationFormatted == "1h 30m")
    }
    
    @Test func formatsDurationZeroMinutes() {
        let episode = EpisodeRecord(
            podcastId: 1,
            guid: "test",
            title: "Test",
            audioURL: "https://example.com/test.mp3",
            duration: 45 // 45 seconds
        )
        
        #expect(episode.durationFormatted == "0m")
    }
    
    @Test func handlesNilDuration() {
        let episode = EpisodeRecord(
            podcastId: 1,
            guid: "test",
            title: "Test",
            audioURL: "https://example.com/test.mp3",
            duration: nil
        )
        
        #expect(episode.durationFormatted == "")
    }
    
    // MARK: - Remaining Time Tests
    
    @Test func calculatesRemainingTime() {
        let episode = EpisodeRecord(
            podcastId: 1,
            guid: "test",
            title: "Test",
            audioURL: "https://example.com/test.mp3",
            duration: 3600, // 1 hour
            playedUpTo: 1800 // 30 minutes played
        )
        
        #expect(episode.remainingTime == 1800)
        #expect(episode.remainingTimeFormatted == "30m left")
    }
    
    @Test func calculatesRemainingTimeWithHours() {
        let episode = EpisodeRecord(
            podcastId: 1,
            guid: "test",
            title: "Test",
            audioURL: "https://example.com/test.mp3",
            duration: 7200, // 2 hours
            playedUpTo: 900 // 15 minutes played
        )
        
        let remaining = episode.remainingTime
        #expect(remaining == 6300) // 1h 45m = 6300 seconds
        #expect(episode.remainingTimeFormatted == "1h 45m left")
    }
    
    @Test func handlesFullyPlayedEpisode() {
        let episode = EpisodeRecord(
            podcastId: 1,
            guid: "test",
            title: "Test",
            audioURL: "https://example.com/test.mp3",
            duration: 1800,
            playedUpTo: 1800
        )
        
        #expect(episode.remainingTime == 0)
        #expect(episode.remainingTimeFormatted == "0m left")
    }
    
    @Test func handlesNilDurationForRemainingTime() {
        let episode = EpisodeRecord(
            podcastId: 1,
            guid: "test",
            title: "Test",
            audioURL: "https://example.com/test.mp3",
            duration: nil,
            playedUpTo: 100
        )
        
        #expect(episode.remainingTime == nil)
        #expect(episode.remainingTimeFormatted == nil)
    }
    
    // MARK: - Playing Status Enum Tests
    
    @Test func playingStatusRawValues() {
        #expect(PlayingStatus.notPlayed.rawValue == 0)
        #expect(PlayingStatus.inProgress.rawValue == 1)
        #expect(PlayingStatus.completed.rawValue == 2)
    }
    
    @Test func playingStatusFromRawValue() {
        #expect(PlayingStatus(rawValue: 0) == .notPlayed)
        #expect(PlayingStatus(rawValue: 1) == .inProgress)
        #expect(PlayingStatus(rawValue: 2) == .completed)
    }
    
    // MARK: - Download Status Enum Tests
    
    @Test func downloadStatusRawValues() {
        #expect(DownloadStatus.notDownloaded.rawValue == 0)
        #expect(DownloadStatus.queued.rawValue == 1)
        #expect(DownloadStatus.downloading.rawValue == 2)
        #expect(DownloadStatus.downloaded.rawValue == 3)
        #expect(DownloadStatus.failed.rawValue == 4)
        #expect(DownloadStatus.paused.rawValue == 5)
    }
    
    @Test func downloadStatusFromRawValue() {
        #expect(DownloadStatus(rawValue: 0) == .notDownloaded)
        #expect(DownloadStatus(rawValue: 1) == .queued)
        #expect(DownloadStatus(rawValue: 2) == .downloading)
        #expect(DownloadStatus(rawValue: 3) == .downloaded)
        #expect(DownloadStatus(rawValue: 4) == .failed)
        #expect(DownloadStatus(rawValue: 5) == .paused)
    }
    
    // MARK: - Auto Download Status Tests
    
    @Test func autoDownloadStatusRawValues() {
        #expect(AutoDownloadStatus.notSpecified.rawValue == 0)
        #expect(AutoDownloadStatus.autoDownloaded.rawValue == 1)
        #expect(AutoDownloadStatus.userDownloaded.rawValue == 2)
        #expect(AutoDownloadStatus.playerStreaming.rawValue == 3)
    }
    
    // MARK: - System Tag Type Tests
    
    @Test func systemTagTypeRawValues() {
        #expect(SystemTagType.mood.rawValue == "mood")
        #expect(SystemTagType.topic.rawValue == "topic")
    }
    
    @Test func systemTagTypeFromRawValue() {
        #expect(SystemTagType(rawValue: "mood") == .mood)
        #expect(SystemTagType(rawValue: "topic") == .topic)
    }
}
