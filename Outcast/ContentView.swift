//
//  ContentView.swift
//  Outcast
//
//  Created by Eran Dror on 11/28/25.
//

import SwiftUI
import GRDB

struct ContentView: View {
    @State private var episodes: [EpisodeWithPodcast] = []
    @State private var selectedEpisode: EpisodeWithPodcast?
    @State private var showPlayer = false
    @State private var showImport = false
    @State private var isRefreshing = false
    @State private var lastRefreshDate: Date?

    var body: some View {
        NavigationStack {
            ZStack {
                // Stark black background
                Color.black.ignoresSafeArea()
                
                if episodes.isEmpty && !isRefreshing {
                    // Empty state
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            headerView
                            
                            // Episodes list
                            LazyVStack(spacing: 0) {
                                ForEach(episodes) { episode in
                                    EpisodeRow(episode: episode) {
                                        selectedEpisode = episode
                                        showPlayer = true
                                    }
                                    
                                    // Divider
                                    Rectangle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 1)
                                        .padding(.leading, 20)
                                }
                            }
                        }
                    }
                    .refreshable {
                        await refreshFeeds()
                    }
                }
                
                // Loading overlay
                if isRefreshing && episodes.isEmpty {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await loadEpisodes()
        }
        .fullScreenCover(item: $selectedEpisode) { episode in
            PlayerView(episode: episode)
        }
        .sheet(isPresented: $showImport) {
            ImportView()
                .onDisappear {
                    Task {
                        await loadEpisodes()
                    }
                }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("For You")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Spacer()
            
            Button {
                showImport = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "headphones.circle")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No Podcasts Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text("Import your podcasts from another app or subscribe to a new one.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showImport = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Podcasts")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(30)
            }
            .padding(.top, 8)
        }
    }
    
    private func loadEpisodes() async {
        do {
            let loaded = try await AppDatabase.shared.readAsync { db in
                try EpisodeWithPodcast.fetchLatest(limit: 100, db: db)
            }
            await MainActor.run {
                episodes = loaded
            }
        } catch {
            print("Failed to load episodes: \(error)")
        }
    }
    
    private func refreshFeeds() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            let refresher = FeedRefresher.shared
            _ = try await refresher.refreshAll()
            await loadEpisodes()
            lastRefreshDate = Date()
        } catch {
            print("Failed to refresh: \(error)")
        }
    }
}

// MARK: - Episode with Podcast Info

struct EpisodeWithPodcast: Identifiable, Sendable {
    let episode: EpisodeRecord
    let podcast: PodcastRecord
    
    var id: String { episode.uuid }
    
    static func fetchLatest(limit: Int, db: Database) throws -> [EpisodeWithPodcast] {
        let request = EpisodeRecord
            .including(required: EpisodeRecord.podcast)
            .order(Column("publishedDate").desc)
            .limit(limit)
        
        return try Row.fetchAll(db, request).map { row in
            EpisodeWithPodcast(
                episode: try EpisodeRecord(row: row),
                podcast: try PodcastRecord(row: row.scopes["podcast"]!)
            )
        }
    }
}

// MARK: - Episode Row

struct EpisodeRow: View {
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

#Preview {
    ContentView()
}
