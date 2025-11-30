//
//  ShowView.swift
//  Outcast
//
//  Main podcast detail screen showing episodes and podcast information
//

import SwiftUI
import GRDB

struct ShowView: View {
    let podcast: PodcastRecord
    @State private var episodes: [EpisodeWithPodcast] = []
    @State private var selectedEpisode: EpisodeWithPodcast?
    @State private var showPlayer = false
    @State private var isHeaderExpanded = false
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Stark black background
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header with podcast info
                    ShowHeaderView(podcast: podcast, isExpanded: $isHeaderExpanded)
                    
                    // Episodes section header
                    if !episodes.isEmpty {
                        HStack {
                            Text("Episodes")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Text("\(episodes.count)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    
                    // Episodes list
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 40)
                    } else if episodes.isEmpty {
                        emptyStateView
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(episodes) { episode in
                                EpisodeListRow(episode: episode) {
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
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await loadEpisodes()
        }
        .fullScreenCover(item: $selectedEpisode) { episode in
            PlayerView(episode: episode)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No Episodes Yet")
                .font(.headline)
                .foregroundStyle(.white)
            
            Text("Check back later for new episodes.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
    
    private func loadEpisodes() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let podcastId = podcast.id else { return }
            
            let loaded = try await AppDatabase.shared.readAsync { db in
                let episodeRecords = try EpisodeRecord.fetchAllForPodcast(podcastId, db: db)
                return episodeRecords.map { episodeRecord in
                    EpisodeWithPodcast(episode: episodeRecord, podcast: podcast)
                }
            }
            
            await MainActor.run {
                episodes = loaded
            }
        } catch {
            print("Failed to load episodes: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        ShowView(
            podcast: PodcastRecord(
                id: 1,
                feedURL: "https://example.com/feed.xml",
                title: "Sample Podcast",
                author: "Sample Author",
                podcastDescription: "This is a sample podcast description that explains what the show is all about.",
                homePageURL: "https://example.com",
                artworkColor: "#FF6B35"
            )
        )
    }
}
