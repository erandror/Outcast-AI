//
//  ImageCache.swift
//  Outcast
//
//  Image caching service for prefetching and storing remote images
//

import SwiftUI

/// Actor-based image cache for prefetching and caching remote images
actor ImageCache {
    static let shared = ImageCache()
    
    private var cache: [String: UIImage] = [:]
    private var inProgressLoads: [String: Task<UIImage?, Never>] = [:]
    
    private init() {}
    
    /// Retrieve a cached image by URL string
    func get(_ urlString: String) -> UIImage? {
        return cache[urlString]
    }
    
    /// Prefetch an image from URL and store in cache
    func prefetch(_ urlString: String) async {
        // Skip if already cached or loading
        guard cache[urlString] == nil, inProgressLoads[urlString] == nil else {
            return
        }
        
        guard let url = URL(string: urlString) else { return }
        
        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                return UIImage(data: data)
            } catch {
                return nil
            }
        }
        
        inProgressLoads[urlString] = task
        
        if let image = await task.value {
            cache[urlString] = image
        }
        
        inProgressLoads.removeValue(forKey: urlString)
    }
    
    /// Prefetch multiple images concurrently
    func prefetchBatch(_ urlStrings: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for urlString in urlStrings {
                group.addTask {
                    await self.prefetch(urlString)
                }
            }
        }
    }
}
