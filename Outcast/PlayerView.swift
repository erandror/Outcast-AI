//
//  PlayerView.swift
//  Outcast
//
//  Created by Eran Dror on 11/28/25.
//

import SwiftUI

struct PlayerView: View {
    let episode: EpisodeWithPodcast
    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    
    private var duration: TimeInterval {
        episode.episode.duration ?? 0
    }
    
    var body: some View {
        ZStack {
            // Stark black background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                // Artwork
                ZStack {
                    if let artworkURL = episode.episode.imageURL ?? episode.podcast.artworkURL,
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
                .frame(width: 280, height: 280)
                .cornerRadius(8)
                .clipped()
                .shadow(color: .white.opacity(0.1), radius: 20)
                
                // Episode info
                VStack(spacing: 8) {
                    Text(episode.episode.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(episode.podcast.title)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 32)
                
                // Progress slider
                VStack(spacing: 8) {
                    Slider(value: $currentTime, in: 0...max(1, duration))
                        .tint(.white)
                        .padding(.horizontal, 32)
                    
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(formatTime(duration))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 40)
                }
                
                // Playback controls
                HStack(spacing: 48) {
                    Button {
                        // Skip back 15 seconds
                        currentTime = max(0, currentTime - 15)
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.white)
                    }
                    
                    Button {
                        // Skip forward 30 seconds
                        currentTime = min(duration, currentTime + 30)
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            currentTime = episode.episode.playedUpTo
        }
        .onDisappear {
            // Save playback position
            Task {
                await savePlaybackPosition()
            }
        }
    }
    
    private var artworkPlaceholder: some View {
        ZStack {
            Color(hexString: episode.podcast.artworkColor ?? "#4ECDC4")
            Text(String(episode.podcast.title.prefix(1)))
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func savePlaybackPosition() async {
        let position = currentTime  // Capture on MainActor first
        let episodeToUpdate = episode.episode
        do {
            try await AppDatabase.shared.writeAsync { db in
                var updatedEpisode = episodeToUpdate
                try updatedEpisode.updatePlaybackPosition(position, db: db)
            }
        } catch {
            print("Failed to save playback position: \(error)")
        }
    }
}

#Preview {
    let podcast = PodcastRecord(
        feedURL: "https://example.com/feed.xml",
        title: "Sample Podcast",
        author: "Sample Author",
        artworkColor: "#FF6B35"
    )
    
    let episode = EpisodeRecord(
        podcastId: 1,
        guid: "sample-guid",
        title: "Sample Episode Title",
        audioURL: "https://example.com/episode.mp3",
        duration: 2847
    )
    
    PlayerView(episode: EpisodeWithPodcast(episode: episode, podcast: podcast))
}
