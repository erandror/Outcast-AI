//
//  ImportCoordinator.swift
//  Outcast
//
//  Manages concurrent background import of podcasts from OPML
//  Inspired by Pocket Casts' OperationQueue-based approach
//

import Foundation
import Combine

/// Coordinates concurrent background refresh of imported podcasts
actor ImportCoordinator {
    
    /// Shared instance
    static let shared = ImportCoordinator()
    
    /// Progress information for ongoing import
    struct ImportProgress: Sendable, Equatable {
        let total: Int
        var completed: Int
        var failed: Int
        var currentPodcast: String?
        
        var isComplete: Bool {
            completed + failed >= total
        }
        
        var successRate: Double {
            guard total > 0 else { return 0 }
            return Double(completed) / Double(total)
        }
    }
    
    /// Current import progress (nil if not importing)
    private(set) var progress: ImportProgress?
    
    /// Whether an import is currently in progress
    private(set) var isImporting = false
    
    /// Maximum number of concurrent podcast refreshes (like Pocket Casts' maxConcurrentOperationCount)
    private let maxConcurrentRefreshes = 5
    
    private init() {}
    
    /// Import podcasts with concurrent background refresh
    /// - Parameter podcasts: Array of podcast records to refresh
    func importPodcasts(_ podcasts: [PodcastRecord]) async {
        guard !isImporting else {
            print("⚠️ Import already in progress, skipping...")
            return
        }
        
        isImporting = true
        progress = ImportProgress(total: podcasts.count, completed: 0, failed: 0, currentPodcast: nil)
        
        print("📥 Starting import of \(podcasts.count) podcasts (max \(maxConcurrentRefreshes) concurrent)")
        
        let startTime = Date()
        let refresher = FeedRefresher.shared
        
        // Use TaskGroup for concurrent refresh with limit
        await withTaskGroup(of: (String, Bool).self) { group in
            var activeCount = 0
            var iterator = podcasts.makeIterator()
            
            // Start initial batch up to maxConcurrentRefreshes
            while activeCount < maxConcurrentRefreshes, let podcast = iterator.next() {
                group.addTask {
                    do {
                        _ = try await refresher.refreshForImport(podcast: podcast)
                        return (podcast.title, true)
                    } catch {
                        print("❌ Failed to refresh \(podcast.title): \(error)")
                        return (podcast.title, false)
                    }
                }
                activeCount += 1
            }
            
            // As tasks complete, add more until all podcasts are processed
            for await (title, success) in group {
                if success {
                    progress?.completed += 1
                    print("✓ Refreshed \(title) (\(progress?.completed ?? 0)/\(podcasts.count))")
                } else {
                    progress?.failed += 1
                    print("✗ Failed \(title) (\(progress?.failed ?? 0) failures)")
                }
                
                // Add next podcast if available
                if let nextPodcast = iterator.next() {
                    group.addTask {
                        do {
                            _ = try await refresher.refreshForImport(podcast: nextPodcast)
                            return (nextPodcast.title, true)
                        } catch {
                            print("❌ Failed to refresh \(nextPodcast.title): \(error)")
                            return (nextPodcast.title, false)
                        }
                    }
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if let finalProgress = progress {
            print("✅ Import complete: \(finalProgress.completed) succeeded, \(finalProgress.failed) failed in \(minutes)m \(seconds)s")
        }
        
        isImporting = false
        progress = nil
    }
    
    /// Get current import progress (if any)
    func getCurrentProgress() -> ImportProgress? {
        return progress
    }
}
