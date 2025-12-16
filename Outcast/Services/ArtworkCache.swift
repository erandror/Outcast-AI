//
//  ArtworkCache.swift
//  Outcast
//
//  Actor-based artwork caching service using Kingfisher
//

import Foundation
import SwiftUI
import Kingfisher

/// Actor-based artwork cache for managing podcast and episode artwork
actor ArtworkCache {
    static let shared = ArtworkCache()
    
    /// Track in-progress prefetch operations
    private var inProgressPrefetches: Set<String> = []
    
    private init() {
        // Configure Kingfisher's default cache
        let cache = ImageCache.default
        
        // Configure disk cache limits
        cache.diskStorage.config.sizeLimit = UInt(200 * 1024 * 1024)  // 200 MB
        cache.diskStorage.config.expiration = .days(180)  // 6 months
        
        // Configure memory cache limits
        cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024  // 50 MB
        cache.memoryStorage.config.countLimit = 100  // Max 100 images in memory
    }
    
    // MARK: - Prefetching
    
    /// Prefetch a single artwork URL
    func prefetch(url: String, for identifier: String) async {
        guard !url.isEmpty,
              let imageURL = URL(string: url),
              !inProgressPrefetches.contains(identifier) else {
            return
        }
        
        // Check if already cached
        let cacheKey = imageURL.absoluteString
        if ImageCache.default.isCached(forKey: cacheKey) {
            return
        }
        
        inProgressPrefetches.insert(identifier)
        
        // Use KingfisherManager for prefetching
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            KingfisherManager.shared.retrieveImage(with: imageURL) { [weak self] _ in
                Task { [weak self] in
                    await self?.markPrefetchComplete(identifier: identifier)
                }
                continuation.resume()
            }
        }
    }
    
    /// Prefetch multiple artwork URLs
    func prefetchBatch(urls: [(url: String, identifier: String)]) async {
        await withTaskGroup(of: Void.self) { group in
            for item in urls {
                group.addTask {
                    await self.prefetch(url: item.url, for: item.identifier)
                }
            }
        }
    }
    
    private func markPrefetchComplete(identifier: String) {
        inProgressPrefetches.remove(identifier)
    }
    
    // MARK: - Cache Checking
    
    /// Check if an artwork URL is cached
    func isCached(url: String) -> Bool {
        guard let imageURL = URL(string: url) else { return false }
        return ImageCache.default.isCached(forKey: imageURL.absoluteString)
    }
    
    /// Retrieve cached image synchronously (from memory only)
    func getCachedImage(url: String) -> UIImage? {
        guard let imageURL = URL(string: url) else { return nil }
        return ImageCache.default.retrieveImageInMemoryCache(forKey: imageURL.absoluteString)
    }
    
    // MARK: - Cache Management
    
    /// Clear cached artwork for a specific URL
    func clearCache(for identifier: String, url: String?) async {
        guard let url = url, let imageURL = URL(string: url) else { return }
        
        ImageCache.default.removeImage(forKey: imageURL.absoluteString)
    }
    
    /// Clear all cached artwork
    func clearAllCache() async {
        ImageCache.default.clearMemoryCache()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ImageCache.default.clearDiskCache {
                continuation.resume()
            }
        }
    }
    
    /// Get cache size in bytes
    func getCacheSize() async -> UInt {
        await withCheckedContinuation { (continuation: CheckedContinuation<UInt, Never>) in
            ImageCache.default.calculateDiskStorageSize { result in
                switch result {
                case .success(let size):
                    continuation.resume(returning: size)
                case .failure:
                    continuation.resume(returning: 0)
                }
            }
        }
    }
}
