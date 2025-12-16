//
//  HistoryView.swift
//  Outcast
//
//  View displaying episode playback history
//

import SwiftUI
import GRDB

struct HistoryView: View {
    @State private var historyEpisodes: [EpisodeWithPodcast] = []
    @State private var isLoading = false
    
    let onPlayEpisode: (EpisodeWithPodcast) -> Void
    let onTapEpisode: (EpisodeWithPodcast) -> Void
    
    var body: some View {
        ScrollView {
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
            }
            .frame(height: 0)
            
            VStack(spacing: 0) {
                if historyEpisodes.isEmpty && !isLoading {
                    emptyStateView
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(historyEpisodes) { episode in
                            HistoryEpisodeRow(
                                episode: episode,
                                onPlay: {
                                    onPlayEpisode(episode)
                                },
                                onTapEpisode: {
                                    onTapEpisode(episode)
                                }
                            )
                            
                            // Divider
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .coordinateSpace(name: "scroll")
        .task {
            await loadHistory()
        }
        .refreshable {
            await loadHistory()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No History Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text("Episodes you play will appear here, so you can easily pick up where you left off.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private func loadHistory() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loaded = try await AppDatabase.shared.readAsync { db in
                try EpisodeWithPodcast.fetchHistory(limit: 100, db: db)
            }
            await MainActor.run {
                historyEpisodes = loaded
            }
        } catch {
            print("Failed to load history: \(error)")
        }
    }
}

// MARK: - History Episode Row

struct HistoryEpisodeRow: View {
    let episode: EpisodeWithPodcast
    let onPlay: () -> Void
    let onTapEpisode: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Artwork - fixed size
            PodcastArtwork(podcast: episode.podcast, size: .episodeRow)
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
                    // Show remaining time or finished status
                    if episode.episode.playingStatus == .completed {
                        Text("Finished")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        if let lastPlayed = episode.episode.lastPlayedAt {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text(lastPlayed, format: .relative(presentation: .named))
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    } else if let remainingFormatted = episode.episode.remainingTimeFormatted {
                        Text(remainingFormatted)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        if let lastPlayed = episode.episode.lastPlayedAt {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text(lastPlayed, format: .relative(presentation: .named))
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    } else if let lastPlayed = episode.episode.lastPlayedAt {
                        // Only show time ago when there's no remaining time or finished status
                        Text(lastPlayed, format: .relative(presentation: .named))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                // Action buttons - below metadata
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
    
    private var playButtonIcon: String {
        switch episode.episode.playingStatus {
        case .inProgress:
            return "play.circle"
        case .completed:
            return "arrow.clockwise.circle"
        case .notPlayed:
            return "play.circle.fill"
        }
    }
}

// MARK: - Previews

#Preview {
    let podcast = PodcastRecord(
        id: 1,
        feedURL: "https://example.com/feed.xml",
        title: "Tech News Daily",
        author: "Tech Network",
        podcastDescription: "Your daily tech news",
        homePageURL: "https://example.com",
        artworkColor: "#FF6B35"
    )
    
    let inProgressEpisode = EpisodeRecord(
        id: 1,
        uuid: "ep-001",
        podcastId: 1,
        guid: "guid-001",
        title: "Episode 1: Getting Started",
        episodeDescription: "The first episode",
        audioURL: "https://example.com/episode1.mp3",
        duration: 3600,
        publishedDate: Date().addingTimeInterval(-86400),
        playedUpTo: 1800,
        playingStatus: .inProgress,
        lastPlayedAt: Date().addingTimeInterval(-3600)
    )
    
    let completedEpisode = EpisodeRecord(
        id: 2,
        uuid: "ep-002",
        podcastId: 1,
        guid: "guid-002",
        title: "Episode 2: Advanced Topics",
        episodeDescription: "The second episode",
        audioURL: "https://example.com/episode2.mp3",
        duration: 2400,
        publishedDate: Date().addingTimeInterval(-172800),
        playedUpTo: 2400,
        playingStatus: .completed,
        lastPlayedAt: Date().addingTimeInterval(-86400)
    )
    
    HistoryView(
        onPlayEpisode: { _ in },
        onTapEpisode: { _ in }
    )
    .background(Color.black)
}
