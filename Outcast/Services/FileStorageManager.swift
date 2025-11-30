//
//  FileStorageManager.swift
//  Outcast
//
//  Manages local file storage for downloaded podcast episodes
//

import Foundation

/// Manages file storage for downloaded podcast episodes
actor FileStorageManager {
    
    static let shared = FileStorageManager()
    
    // MARK: - Directory URLs
    
    /// Main podcasts directory for permanent downloads
    nonisolated let podcastsDirectory: URL
    
    /// Temporary directory for in-progress downloads
    nonisolated let tempDownloadsDirectory: URL
    
    /// Optional streaming cache directory
    nonisolated let streamingCacheDirectory: URL
    
    // MARK: - Initialization
    
    private init() {
        let fileManager = FileManager.default
        
        // Get base directories
        guard let documentsURL = try? fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ),
        let cachesURL = try? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            fatalError("Failed to get system directories")
        }
        
        // Set up directory URLs
        self.podcastsDirectory = documentsURL.appendingPathComponent("podcasts", isDirectory: true)
        self.tempDownloadsDirectory = cachesURL.appendingPathComponent("temp_downloads", isDirectory: true)
        self.streamingCacheDirectory = documentsURL.appendingPathComponent("streaming_cache", isDirectory: true)
        
        // Create directories synchronously
        do {
            try fileManager.createDirectory(at: podcastsDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: tempDownloadsDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: streamingCacheDirectory, withIntermediateDirectories: true)
            
            // Set to exclude from backup
            var podcastsResourceURL = podcastsDirectory
            var podcastsResourceValues = URLResourceValues()
            podcastsResourceValues.isExcludedFromBackup = true
            try podcastsResourceURL.setResourceValues(podcastsResourceValues)
            
            var streamingResourceURL = streamingCacheDirectory
            var streamingResourceValues = URLResourceValues()
            streamingResourceValues.isExcludedFromBackup = true
            try streamingResourceURL.setResourceValues(streamingResourceValues)
        } catch {
            fatalError("Failed to setup file storage directories: \(error)")
        }
    }
    
    /// Create a directory if it doesn't exist
    private func createDirectoryIfNeeded(at url: URL, excludeFromBackup: Bool) throws {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        // Set to exclude from backup if needed
        if excludeFromBackup {
            var resourceURL = url
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try resourceURL.setResourceValues(resourceValues)
        }
    }
    
    // MARK: - File Path Methods
    
    /// Get the file URL for a downloaded episode
    func fileURL(for episodeUUID: String, fileExtension: String) -> URL {
        let filename = "\(episodeUUID).\(fileExtension)"
        return podcastsDirectory.appendingPathComponent(filename)
    }
    
    /// Get the temp file URL for an episode being downloaded
    func tempFileURL(for episodeUUID: String) -> URL {
        let filename = "\(episodeUUID).tmp"
        return tempDownloadsDirectory.appendingPathComponent(filename)
    }
    
    /// Get the streaming cache file URL
    func streamingCacheURL(for episodeUUID: String, fileExtension: String) -> URL {
        let filename = "\(episodeUUID).\(fileExtension)"
        return streamingCacheDirectory.appendingPathComponent(filename)
    }
    
    // MARK: - File Operations
    
    /// Check if a file exists for an episode
    func fileExists(for episodeUUID: String, fileExtension: String) -> Bool {
        let url = fileURL(for: episodeUUID, fileExtension: fileExtension)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Get the size of a downloaded file
    func fileSize(for episodeUUID: String, fileExtension: String) -> Int64? {
        let url = fileURL(for: episodeUUID, fileExtension: fileExtension)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
    
    /// Move a temp file to the permanent location
    func moveFromTemp(episodeUUID: String, fileExtension: String) throws -> URL {
        let sourceURL = tempFileURL(for: episodeUUID)
        let destinationURL = fileURL(for: episodeUUID, fileExtension: fileExtension)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
    
    /// Delete a downloaded episode file
    func deleteFile(for episodeUUID: String, fileExtension: String) throws {
        let url = fileURL(for: episodeUUID, fileExtension: fileExtension)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    /// Delete a temp file
    func deleteTempFile(for episodeUUID: String) throws {
        let url = tempFileURL(for: episodeUUID)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    /// Save resume data for a download
    func saveResumeData(_ data: Data, for episodeUUID: String) throws {
        let url = tempFileURL(for: episodeUUID)
        try data.write(to: url, options: .atomic)
    }
    
    /// Load resume data for a download
    func loadResumeData(for episodeUUID: String) -> Data? {
        let url = tempFileURL(for: episodeUUID)
        return try? Data(contentsOf: url)
    }
    
    // MARK: - Storage Management
    
    /// Get total size of all downloaded files
    func totalStorageUsed() async throws -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: podcastsDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        let allURLs = enumerator.allObjects.compactMap { $0 as? URL }
        for fileURL in allURLs {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
    
    /// Get available disk space
    func availableDiskSpace() -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(
            forPath: podcastsDirectory.path
        ) else {
            return nil
        }
        return attributes[.systemFreeSize] as? Int64
    }
    
    /// Clean up orphaned files (files with no corresponding database entry)
    func cleanupOrphanedFiles(validUUIDs: Set<String>) async throws {
        let fileManager = FileManager.default
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: podcastsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        
        for fileURL in files {
            let filename = fileURL.deletingPathExtension().lastPathComponent
            if !validUUIDs.contains(filename) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    /// Clean up old streaming cache files
    func cleanupStreamingCache(olderThan days: Int = 7) async throws {
        let fileManager = FileManager.default
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: streamingCacheDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return
        }
        
        for fileURL in files {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = resourceValues.creationDate,
                  creationDate < cutoffDate else {
                continue
            }
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    // MARK: - File Extension Helpers
    
    /// Determine file extension from MIME type or URL
    func fileExtension(from mimeType: String?, or url: String) -> String {
        // Try to get from MIME type first
        if let mimeType = mimeType {
            switch mimeType.lowercased() {
            case "audio/mpeg", "audio/mp3":
                return "mp3"
            case "audio/mp4", "audio/m4a":
                return "m4a"
            case "audio/ogg":
                return "ogg"
            case "audio/wav":
                return "wav"
            case "audio/aac":
                return "aac"
            case "video/mp4":
                return "mp4"
            default:
                break
            }
        }
        
        // Try to get from URL
        if let urlObj = URL(string: url),
           !urlObj.pathExtension.isEmpty {
            return urlObj.pathExtension
        }
        
        // Default to mp3
        return "mp3"
    }
}
