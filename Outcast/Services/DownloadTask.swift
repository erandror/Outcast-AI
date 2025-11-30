//
//  DownloadTask.swift
//  Outcast
//
//  Model for tracking individual download tasks
//

import Foundation

/// Represents an active download task
struct DownloadTask: Sendable {
    let episodeUUID: String
    let url: URL
    let fileExtension: String
    var urlSessionTask: URLSessionDownloadTask?
    var startTime: Date
    var bytesDownloaded: Int64
    var totalBytes: Int64
    var autoDownloadStatus: AutoDownloadStatus
    
    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(totalBytes)
    }
    
    init(
        episodeUUID: String,
        url: URL,
        fileExtension: String,
        autoDownloadStatus: AutoDownloadStatus = .userDownloaded
    ) {
        self.episodeUUID = episodeUUID
        self.url = url
        self.fileExtension = fileExtension
        self.startTime = Date()
        self.bytesDownloaded = 0
        self.totalBytes = 0
        self.autoDownloadStatus = autoDownloadStatus
    }
}
