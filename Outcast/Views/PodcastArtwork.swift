//
//  PodcastArtwork.swift
//  Outcast
//
//  Unified SwiftUI view for displaying podcast artwork with caching
//

import SwiftUI
import Kingfisher

/// Size presets for podcast artwork
enum ArtworkSize {
    case small      // 56pt - List rows, mini player
    case episodeRow // 110pt - Episode list rows
    case medium     // 150pt - Grid view
    case large      // 300pt - Detail pages, now playing
    
    var dimension: CGFloat {
        switch self {
        case .small: return 56
        case .episodeRow: return 110
        case .medium: return 150
        case .large: return 300
        }
    }
}

/// Unified view for displaying podcast artwork with robust caching
struct PodcastArtwork: View {
    let artworkURL: String?
    let placeholderColor: String?
    let placeholderTitle: String
    let size: ArtworkSize
    
    init(
        podcast: PodcastRecord,
        size: ArtworkSize = .medium
    ) {
        self.artworkURL = podcast.artworkURL
        self.placeholderColor = podcast.artworkColor
        self.placeholderTitle = podcast.title
        self.size = size
    }
    
    init(
        artworkURL: String?,
        placeholderColor: String?,
        placeholderTitle: String,
        size: ArtworkSize = .medium
    ) {
        self.artworkURL = artworkURL
        self.placeholderColor = placeholderColor
        self.placeholderTitle = placeholderTitle
        self.size = size
    }
    
    var body: some View {
        Group {
            if let artworkURL = artworkURL,
               let url = URL(string: artworkURL) {
                KFImage(url)
                    .cacheOriginalImage()
                    .fade(duration: 0.15)
                    .placeholder {
                        placeholderView
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .cornerRadius(cornerRadius)
        .clipped()
    }
    
    private var placeholderView: some View {
        ZStack {
            Color(hexString: placeholderColor ?? "#4ECDC4")
            
            Text(String(placeholderTitle.prefix(1).uppercased()))
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    private var cornerRadius: CGFloat {
        switch size {
        case .small: return 4
        case .episodeRow: return 8
        case .medium: return 8
        case .large: return 12
        }
    }
    
    private var fontSize: CGFloat {
        switch size {
        case .small: return 20
        case .episodeRow: return 32
        case .medium: return 48
        case .large: return 96
        }
    }
}

// MARK: - Episode Artwork

/// View for displaying episode-specific artwork (falls back to podcast artwork)
struct EpisodeArtwork: View {
    let episode: EpisodeRecord
    let podcast: PodcastRecord
    let size: ArtworkSize
    
    var body: some View {
        PodcastArtwork(
            artworkURL: episode.imageURL ?? podcast.artworkURL,
            placeholderColor: podcast.artworkColor,
            placeholderTitle: podcast.title,
            size: size
        )
    }
}

// MARK: - Previews

#Preview("Podcast Artwork - Medium") {
    PodcastArtwork(
        artworkURL: "https://example.com/artwork.jpg",
        placeholderColor: "#FF6B6B",
        placeholderTitle: "Tech Podcast",
        size: .medium
    )
    .padding()
    .background(Color.black)
}

#Preview("Podcast Artwork - Placeholder") {
    HStack(spacing: 20) {
        PodcastArtwork(
            artworkURL: nil,
            placeholderColor: "#4ECDC4",
            placeholderTitle: "Design",
            size: .small
        )
        
        PodcastArtwork(
            artworkURL: nil,
            placeholderColor: "#FF6B6B",
            placeholderTitle: "Tech",
            size: .medium
        )
        
        PodcastArtwork(
            artworkURL: nil,
            placeholderColor: "#95E1D3",
            placeholderTitle: "News",
            size: .large
        )
    }
    .padding()
    .background(Color.black)
}

