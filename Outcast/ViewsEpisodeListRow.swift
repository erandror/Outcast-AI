//
//  EpisodeListRow.swift
//  Outcast
//
//  Reusable episode row component
//

import SwiftUI

/// Reusable episode row for displaying episode information
struct EpisodeListRow: View {
    let episode: EpisodeWithPodcast
    let onPlay: () -> Void
    
    var body: some View {
        Button {
            onPlay()
        } label: {
            HStack(alignment: .top, spacing: 16) {
                // Artwork
                ZStack {
                    if let artworkURL = episode.podcast.artworkURL,
                       let url = URL(string: artworkURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            artworkPlaceholder
                        }
                    } else {
                        artworkPlaceholder
                    }
                }
                .frame(width: 80, height: 80)
                .cornerRadius(4)
                .clipped()
                
                // Episode info
                VStack(alignment: .leading, spacing: 6) {
                    Text(episode.podcast.title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    Text(episode.episode.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        if let duration = episode.episode.duration {
                            Text(formatDuration(duration))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        if let date = episode.episode.publishedDate {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text(date, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                // Play button
                Image(systemName: playButtonIcon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .padding(20)
        }
        .buttonStyle(.plain)
    }
    
    private var artworkPlaceholder: some View {
        ZStack {
            Color(hexString: episode.podcast.artworkColor ?? "#4ECDC4")
            Text(String(episode.podcast.title.prefix(1)))
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }
    
    private var playButtonIcon: String {
        switch episode.episode.playingStatus {
        case .inProgress:
            return "play.circle"
        case .completed:
            return "checkmark.circle"
        case .notPlayed:
            return "play.circle.fill"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
