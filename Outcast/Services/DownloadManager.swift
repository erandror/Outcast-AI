//
//  DownloadManager.swift
//  Outcast
//
//  Actor-based download manager for podcast episodes
//

import Foundation
import GRDB

/// Manages podcast episode downloads with background support
actor DownloadManager: NSObject {
    
    static let shared = DownloadManager()
    
    // MARK: - Properties
    
    private var activeDownloads: [String: DownloadTask] = [:]
    private var progressCallbacks: [String: @Sendable (Double) -> Void] = [:]
    
    private let fileStorage = FileStorageManager.shared
    private let database = AppDatabase.shared
    
    // URLSession for wifi-only downloads
    private lazy var wifiSession: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.outcast.download.wifi"
        )
        config.allowsExpensiveNetworkAccess = false
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.httpMaximumConnectionsPerHost = 2
        config.timeoutIntervalForRequest = 60
        return URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }()
    
    // URLSession for cellular downloads
    private lazy var cellularSession: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.outcast.download.cellular"
        )
        config.allowsExpensiveNetworkAccess = true
        config.allowsCellularAccess = true
        config.sessionSendsLaunchEvents = true
        config.httpMaximumConnectionsPerHost = 2
        config.timeoutIntervalForRequest = 60
        return URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Start downloading an episode
    func downloadEpisode(
        episodeUUID: String,
        url: String,
        mimeType: String?,
        allowCellular: Bool = false,
        autoDownloadStatus: AutoDownloadStatus = .userDownloaded,
        progressCallback: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        guard let downloadURL = URL(string: url) else {
            throw DownloadError.invalidURL
        }
        
        // Check if already downloading
        if activeDownloads[episodeUUID] != nil {
            return
        }
        
        // Determine file extension
        let fileExtension = await fileStorage.fileExtension(from: mimeType, or: url)
        
        // Check if file already exists
        if await fileStorage.fileExists(for: episodeUUID, fileExtension: fileExtension) {
            throw DownloadError.alreadyDownloaded
        }
        
        // Create download task
        var downloadTask = DownloadTask(
            episodeUUID: episodeUUID,
            url: downloadURL,
            fileExtension: fileExtension,
            autoDownloadStatus: autoDownloadStatus
        )
        
        // Update database to queued status
        try await database.writeAsync { db in
            if var episode = try EpisodeRecord.filter(Column("uuid") == episodeUUID).fetchOne(db) {
                episode.downloadStatus = .queued
                episode.downloadTaskIdentifier = episodeUUID
                episode.autoDownloadStatus = autoDownloadStatus
                try episode.update(db)
            }
        }
        
        // Check for resume data
        let tempURL = await fileStorage.tempFileURL(for: episodeUUID)
        let session = allowCellular ? cellularSession : wifiSession
        
        let urlSessionTask: URLSessionDownloadTask
        if let resumeData = await fileStorage.loadResumeData(for: episodeUUID) {
            urlSessionTask = session.downloadTask(withResumeData: resumeData)
        } else {
            var request = URLRequest(url: downloadURL)
            request.setValue("Outcast/1.0", forHTTPHeaderField: "User-Agent")
            urlSessionTask = session.downloadTask(with: request)
        }
        
        downloadTask.urlSessionTask = urlSessionTask
        activeDownloads[episodeUUID] = downloadTask
        
        if let progressCallback = progressCallback {
            progressCallbacks[episodeUUID] = progressCallback
        }
        
        // Update status to downloading
        try await database.writeAsync { db in
            if var episode = try EpisodeRecord.filter(Column("uuid") == episodeUUID).fetchOne(db) {
                episode.downloadStatus = .downloading
                try episode.update(db)
            }
        }
        
        urlSessionTask.resume()
    }
    
    /// Cancel a download
    func cancelDownload(episodeUUID: String) async throws {
        guard let downloadTask = activeDownloads[episodeUUID] else {
            return
        }
        
        // Cancel the URLSession task and save resume data
        if let urlSessionTask = downloadTask.urlSessionTask {
            urlSessionTask.cancel { resumeData in
                Task {
                    if let data = resumeData {
                        try? await self.fileStorage.saveResumeData(data, for: episodeUUID)
                    }
                }
            }
        }
        
        activeDownloads.removeValue(forKey: episodeUUID)
        progressCallbacks.removeValue(forKey: episodeUUID)
        
        // Update database
        try await database.writeAsync { db in
            if var episode = try EpisodeRecord.filter(Column("uuid") == episodeUUID).fetchOne(db) {
                episode.downloadStatus = .paused
                episode.downloadTaskIdentifier = nil
                try episode.update(db)
            }
        }
    }
    
    /// Delete a downloaded episode
    func deleteDownload(episodeUUID: String, fileExtension: String) async throws {
        // Cancel if currently downloading
        try await cancelDownload(episodeUUID: episodeUUID)
        
        // Delete the file
        try await fileStorage.deleteFile(for: episodeUUID, fileExtension: fileExtension)
        try await fileStorage.deleteTempFile(for: episodeUUID)
        
        // Update database
        try await database.writeAsync { db in
            if var episode = try EpisodeRecord.filter(Column("uuid") == episodeUUID).fetchOne(db) {
                episode.downloadStatus = .notDownloaded
                episode.isDownloaded = false
                episode.localFilePath = nil
                episode.downloadedFileSize = nil
                episode.downloadProgress = 0
                episode.downloadError = nil
                try episode.update(db)
            }
        }
    }
    
    /// Get download progress for an episode
    func downloadProgress(for episodeUUID: String) -> Double? {
        return activeDownloads[episodeUUID]?.progress
    }
    
    /// Check if an episode is currently downloading
    func isDownloading(episodeUUID: String) -> Bool {
        return activeDownloads[episodeUUID] != nil
    }
    
    /// Get all active downloads
    func activeDownloadUUIDs() -> [String] {
        return Array(activeDownloads.keys)
    }
    
    /// Resume all paused downloads
    func resumeAllDownloads() async throws {
        let pausedEpisodes = try await database.readAsync { db in
            try EpisodeRecord
                .filter(Column("downloadStatus") == DownloadStatus.paused.rawValue)
                .fetchAll(db)
        }
        
        for episode in pausedEpisodes {
            try? await downloadEpisode(
                episodeUUID: episode.uuid,
                url: episode.audioURL,
                mimeType: episode.audioMimeType,
                allowCellular: false,
                autoDownloadStatus: episode.autoDownloadStatus
            )
        }
    }
    
    // MARK: - Internal Methods
    
    /// Handle download completion
    nonisolated func handleDownloadCompletion(
        episodeUUID: String,
        location: URL,
        error: Error?
    ) {
        Task {
            await self._handleDownloadCompletion(
                episodeUUID: episodeUUID,
                location: location,
                error: error
            )
        }
    }
    
    private func _handleDownloadCompletion(
        episodeUUID: String,
        location: URL,
        error: Error?
    ) async {
        guard let downloadTask = activeDownloads[episodeUUID] else {
            return
        }
        
        if let error = error {
            // Handle error
            do {
                try await database.writeAsync { db in
                    if var episode = try EpisodeRecord.filter(Column("uuid") == episodeUUID).fetchOne(db) {
                        episode.downloadStatus = .failed
                        episode.downloadError = error.localizedDescription
                        episode.downloadTaskIdentifier = nil
                        try episode.update(db)
                    }
                }
            } catch {
                print("Failed to update episode after download error: \(error)")
            }
            
            activeDownloads.removeValue(forKey: episodeUUID)
            progressCallbacks.removeValue(forKey: episodeUUID)
            return
        }
        
        // Move file to permanent location
        do {
            // Copy from temporary location first
            let tempURL = await fileStorage.tempFileURL(for: episodeUUID)
            try FileManager.default.copyItem(at: location, to: tempURL)
            
            // Move to permanent location
            let finalURL = try await fileStorage.moveFromTemp(
                episodeUUID: episodeUUID,
                fileExtension: downloadTask.fileExtension
            )
            
            let fileSize = await fileStorage.fileSize(
                for: episodeUUID,
                fileExtension: downloadTask.fileExtension
            )
            
            // Update database
            try await database.writeAsync { db in
                if var episode = try EpisodeRecord.filter(Column("uuid") == episodeUUID).fetchOne(db) {
                    episode.downloadStatus = .downloaded
                    episode.isDownloaded = true
                    episode.localFilePath = finalURL.lastPathComponent
                    episode.downloadedFileSize = fileSize
                    episode.downloadProgress = 1.0
                    episode.downloadError = nil
                    episode.downloadTaskIdentifier = nil
                    try episode.update(db)
                }
            }
            
            // Clean up temp file
            try? await fileStorage.deleteTempFile(for: episodeUUID)
            
        } catch {
            print("Failed to move downloaded file: \(error)")
            
            try? await database.writeAsync { db in
                if var episode = try EpisodeRecord.filter(Column("uuid") == episodeUUID).fetchOne(db) {
                    episode.downloadStatus = .failed
                    episode.downloadError = "Failed to save file: \(error.localizedDescription)"
                    try episode.update(db)
                }
            }
        }
        
        activeDownloads.removeValue(forKey: episodeUUID)
        progressCallbacks.removeValue(forKey: episodeUUID)
    }
    
    /// Handle download progress
    nonisolated func handleDownloadProgress(
        episodeUUID: String,
        bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpected: Int64
    ) {
        Task {
            await self._handleDownloadProgress(
                episodeUUID: episodeUUID,
                bytesWritten: bytesWritten,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpected: totalBytesExpected
            )
        }
    }
    
    private func _handleDownloadProgress(
        episodeUUID: String,
        bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpected: Int64
    ) async {
        guard var downloadTask = activeDownloads[episodeUUID] else {
            return
        }
        
        downloadTask.bytesDownloaded = totalBytesWritten
        downloadTask.totalBytes = totalBytesExpected
        activeDownloads[episodeUUID] = downloadTask
        
        let progress = downloadTask.progress
        
        // Call progress callback
        if let callback = progressCallbacks[episodeUUID] {
            callback(progress)
        }
        
        // Update database every 5% progress
        let progressPercent = Int(progress * 100)
        if progressPercent % 5 == 0 {
            try? await database.writeAsync { db in
                if var episode = try EpisodeRecord.filter(Column("uuid") == episodeUUID).fetchOne(db) {
                    episode.downloadProgress = progress
                    try episode.update(db)
                }
            }
        }
    }
}

// MARK: - Error Types

enum DownloadError: LocalizedError {
    case invalidURL
    case alreadyDownloaded
    case downloadFailed(String)
    case insufficientSpace
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .alreadyDownloaded:
            return "Episode already downloaded"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .insufficientSpace:
            return "Not enough storage space"
        }
    }
}
