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
    let onTapEpisode: () -> Void
    
    private let artworkSize: CGFloat = 110
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Artwork - fixed size
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
            .frame(width: artworkSize, height: artworkSize)
            .cornerRadius(4)
            .clipped()
            .onTapGesture {
                onTapEpisode()
            }
            
            // Episode info - full width to the right of artwork
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.podcast.title)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                
                Text(episode.episode.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 4) {
                    if let duration = episode.episode.duration {
                        Text(formatDuration(duration))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    if let date = episode.episode.publishedDate {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text(date, format: .relative(presentation: .named))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                // Action buttons - below publish time
                HStack(spacing: 8) {
                    // Play button
                    Button {
                        onPlay()
                    } label: {
                        Image(systemName: playButtonIcon)
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // Download button
                    DownloadButton(episode: episode.episode)
                        .frame(width: 36, height: 36)
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onTapGesture {
                onTapEpisode()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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

// MARK: - Previews

#Preview("iPhone 15 Pro Max") {
    let podcast = PodcastRecord(
        id: 1,
        feedURL: "https://example.com/feed.xml",
        title: "The Daily Technology News Podcast",
        author: "Tech News Network",
        podcastDescription: "Your daily source for tech news",
        homePageURL: "https://example.com",
        artworkColor: "#FF6B35"
    )
    
    let episode = EpisodeRecord(
        id: 1,
        uuid: "ep-001",
        podcastId: 1,
        guid: "guid-001",
        title: "Breaking: Apple Announces Revolutionary New AI Features for iPhone",
        episodeDescription: "In this episode we discuss the latest Apple announcements.",
        audioURL: "https://example.com/episode.mp3",
        duration: 3600,
        publishedDate: Date().addingTimeInterval(-86400)
    )
    
    VStack(spacing: 0) {
        EpisodeListRow(
            episode: EpisodeWithPodcast(episode: episode, podcast: podcast),
            onPlay: {},
            onTapEpisode: {}
        )
        .background(Color.black)
        
        Divider()
    }
}

#Preview("iPhone SE") {
    let podcast = PodcastRecord(
        id: 1,
        feedURL: "https://example.com/feed.xml",
        title: "The Daily Technology News Podcast",
        author: "Tech News Network",
        podcastDescription: "Your daily source for tech news",
        homePageURL: "https://example.com",
        artworkColor: "#4ECDC4"
    )
    
    let episode = EpisodeRecord(
        id: 1,
        uuid: "ep-001",
        podcastId: 1,
        guid: "guid-001",
        title: "Breaking: Apple Announces Revolutionary New AI Features for iPhone",
        episodeDescription: "In this episode we discuss the latest Apple announcements.",
        audioURL: "https://example.com/episode.mp3",
        duration: 2700,
        publishedDate: Date().addingTimeInterval(-172800)
    )
    
    VStack(spacing: 0) {
        EpisodeListRow(
            episode: EpisodeWithPodcast(episode: episode, podcast: podcast),
            onPlay: {},
            onTapEpisode: {}
        )
        .background(Color.black)
        
        Divider()
    }
}

#Preview("Multiple Episodes") {
    let podcast = PodcastRecord(
        id: 1,
        feedURL: "https://example.com/feed.xml",
        title: "Short Title Pod",
        author: "Author",
        podcastDescription: "Description",
        homePageURL: "https://example.com",
        artworkColor: "#9B59B6"
    )
    
    let episodes = [
        EpisodeRecord(
            id: 1,
            uuid: "ep-001",
            podcastId: 1,
            guid: "guid-001",
            title: "Very Long Episode Title That Should Wrap to Two Lines Gracefully",
            episodeDescription: "Description",
            audioURL: "https://example.com/episode1.mp3",
            duration: 5400,
            publishedDate: Date()
        ),
        EpisodeRecord(
            id: 2,
            uuid: "ep-002",
            podcastId: 1,
            guid: "guid-002",
            title: "Short Title",
            episodeDescription: "Description",
            audioURL: "https://example.com/episode2.mp3",
            duration: 1200,
            publishedDate: Date().addingTimeInterval(-86400)
        )
    ]
    
    ScrollView {
        LazyVStack(spacing: 0) {
            ForEach(episodes) { episode in
                EpisodeListRow(
                    episode: EpisodeWithPodcast(episode: episode, podcast: podcast),
                    onPlay: {},
                    onTapEpisode: {}
                )
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }
    .background(Color.black)
}
