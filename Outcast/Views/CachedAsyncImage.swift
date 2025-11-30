//
//  CachedAsyncImage.swift
//  Outcast
//
//  Cached wrapper around AsyncImage that checks cache first
//

import SwiftUI

/// AsyncImage wrapper that uses ImageCache for faster loading
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var cachedImage: UIImage?
    
    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                content(Image(uiImage: cachedImage))
            } else if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        content(image)
                    case .failure, .empty:
                        placeholder()
                    @unknown default:
                        placeholder()
                    }
                }
            } else {
                placeholder()
            }
        }
        .task(id: url?.absoluteString) {
            guard let urlString = url?.absoluteString else { return }
            cachedImage = await ImageCache.shared.get(urlString)
        }
    }
}
