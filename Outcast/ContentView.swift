//
//  ContentView.swift
//  Outcast
//
//  Created by Eran Dror on 11/28/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.releaseDate, order: .reverse) private var episodes: [Episode]
    @State private var selectedEpisode: Episode?
    @State private var showPlayer = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Stark black background
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("For You")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                        
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
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Load sample data on first launch
            SampleData.createSampleEpisodes(in: modelContext)
        }
        .fullScreenCover(item: $selectedEpisode) { episode in
            PlayerView(episode: episode)
        }
    }
}

struct EpisodeRow: View {
    let episode: Episode
    let onPlay: () -> Void
    
    var body: some View {
        Button {
            onPlay()
        } label: {
            HStack(alignment: .top, spacing: 16) {
                // Artwork
                ZStack {
                    Color(hex: episode.artworkColor)
                    Text(String(episode.podcastTitle.prefix(1)))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .frame(width: 80, height: 80)
                .cornerRadius(4)
                
                // Episode info
                VStack(alignment: .leading, spacing: 6) {
                    Text(episode.podcastTitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    Text(episode.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        Text(episode.durationFormatted)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text("•")
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text(episode.releaseDate, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Play button
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .padding(20)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Episode.self, Podcast.self, configurations: config)
    
    // Add sample data to preview
    SampleData.createSampleEpisodes(in: container.mainContext)
    
    return ContentView()
        .modelContainer(container)
}
