//
//  PlayerView.swift
//  Outcast
//
//  Created by Eran Dror on 11/28/25.
//

import SwiftUI
import GRDB

struct PlayerView: View {
    let episodes: [EpisodeWithPodcast]
    let startIndex: Int
    let onEpisodeUpdated: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playbackManager = PlaybackManager.shared
    @State private var showingPodcastDetail = false
    @State private var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var isCurrentEpisodeSaved: Bool = false
    
    init(episodes: [EpisodeWithPodcast], startIndex: Int, onEpisodeUpdated: (() -> Void)? = nil) {
        self.episodes = episodes
        self.startIndex = startIndex
        self.onEpisodeUpdated = onEpisodeUpdated
        _currentIndex = State(initialValue: startIndex)
    }
    
    private var currentEpisode: EpisodeWithPodcast {
        episodes[currentIndex]
    }
    
    private var hasPrevious: Bool {
        currentIndex > 0
    }
    
    private var hasNext: Bool {
        currentIndex < episodes.count - 1
    }
    
    private var duration: TimeInterval {
        playbackManager.duration > 0 ? playbackManager.duration : (currentEpisode.episode.duration ?? 0)
    }
    
    private var currentTime: TimeInterval {
        playbackManager.currentTime
    }
    
    private var isPlaying: Bool {
        playbackManager.isPlaying
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Stark black background
                Color.black.ignoresSafeArea()
                
                // Episode cards with offsets for swipe animation
                ZStack {
                    // Previous episode (above current)
                    if hasPrevious {
                        episodeCard(for: episodes[currentIndex - 1], offset: -geometry.size.height + dragOffset)
                    }
                    
                    // Current episode
                    episodeCard(for: currentEpisode, offset: dragOffset)
                    
                    // Next episode (below current)
                    if hasNext {
                        episodeCard(for: episodes[currentIndex + 1], offset: geometry.size.height + dragOffset)
                    }
                }
                
                // Close button overlay
                VStack {
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
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !isAnimating else { return }
                        
                        let translation = value.translation.height
                        
                        // Allow drag only if there's content in that direction
                        if translation < 0 && hasNext {
                            // Dragging up to next episode
                            dragOffset = translation
                        } else if translation > 0 && hasPrevious {
                            // Dragging down to previous episode
                            dragOffset = translation
                        } else if (translation < 0 && !hasNext) || (translation > 0 && !hasPrevious) {
                            // Resistance at boundaries - reduce drag distance
                            dragOffset = translation * 0.2
                        }
                    }
                    .onEnded { value in
                        guard !isAnimating else { return }
                        
                        let threshold: CGFloat = 100
                        let translation = value.translation.height
                        
                        if translation < -threshold && hasNext {
                            // Swipe up - go to next
                            goToNext(screenHeight: geometry.size.height)
                        } else if translation > threshold && hasPrevious {
                            // Swipe down - go to previous
                            goToPrevious(screenHeight: geometry.size.height)
                        } else {
                            // Snap back to current
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .task {
            // Load episode into playback manager and start playing
            await loadCurrentEpisode()
            // Prefetch adjacent episode images
            await prefetchAdjacentImages()
        }
        .sheet(isPresented: $showingPodcastDetail) {
            NavigationStack {
                ShowView(podcast: currentEpisode.podcast)
            }
        }
    }
    
    private func goToNext(screenHeight: CGFloat) {
        guard hasNext && !isAnimating else { return }
        
        isAnimating = true
        
        // Animate slide up to next episode
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dragOffset = -screenHeight
        }
        
        // Update index and reset offset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            currentIndex += 1
            dragOffset = 0
            isAnimating = false
            
            // Load new episode and prefetch adjacent images
            Task {
                await loadCurrentEpisode()
                await prefetchAdjacentImages()
            }
        }
    }
    
    private func goToPrevious(screenHeight: CGFloat) {
        guard hasPrevious && !isAnimating else { return }
        
        isAnimating = true
        
        // Animate slide down to previous episode
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dragOffset = screenHeight
        }
        
        // Update index and reset offset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            currentIndex -= 1
            dragOffset = 0
            isAnimating = false
            
            // Load new episode and prefetch adjacent images
            Task {
                await loadCurrentEpisode()
                await prefetchAdjacentImages()
            }
        }
    }
    
    @ViewBuilder
    private func episodeCard(for episode: EpisodeWithPodcast, offset: CGFloat) -> some View {
        VStack(spacing: 32) {
            // Top spacer
            Spacer()
            
            // Artwork
            EpisodeArtwork(
                episode: episode.episode,
                podcast: episode.podcast,
                size: .large
            )
            .frame(width: 280, height: 280)
            .shadow(color: .white.opacity(0.1), radius: 20)
            
            // Episode info
            VStack(spacing: 8) {
                Text(episode.episode.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Button {
                    showingPodcastDetail = true
                } label: {
                    Text(episode.podcast.title)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 32)
            
            // Progress slider
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: { newValue in
                            Task {
                                await playbackManager.seek(to: newValue)
                            }
                        }
                    ),
                    in: 0...max(1, duration)
                )
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
                    Task {
                        await playbackManager.skipBackward(by: 15)
                    }
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundStyle(.white)
                }
                
                Button {
                    playbackManager.togglePlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.white)
                }
                
                Button {
                    Task {
                        await playbackManager.skipForward(by: 30)
                    }
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.title)
                        .foregroundStyle(.white)
                }
                
                Button {
                    Task {
                        await toggleSaved()
                    }
                } label: {
                    Image(systemName: isCurrentEpisodeSaved ? "bookmark.fill" : "bookmark")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
            
            // Bottom spacer
            Spacer()
        }
        .offset(y: offset)
    }
    
    private func loadCurrentEpisode() async {
        do {
            try await playbackManager.load(episode: currentEpisode.episode, autoPlay: true)
        } catch {
            print("Failed to load episode: \(error)")
        }
        
        // Always load saved state from database (the episodes array may be stale)
        await loadSavedState()
    }
    
    private func loadSavedState() async {
        guard let episodeId = currentEpisode.episode.id else {
            isCurrentEpisodeSaved = currentEpisode.episode.isSaved
            return
        }
        
        do {
            let savedState = try await AppDatabase.shared.readAsync { db in
                try EpisodeRecord
                    .filter(Column("id") == episodeId)
                    .fetchOne(db)?
                    .isSaved ?? false
            }
            await MainActor.run {
                isCurrentEpisodeSaved = savedState
            }
        } catch {
            print("Failed to load saved state: \(error)")
            isCurrentEpisodeSaved = currentEpisode.episode.isSaved
        }
    }
    
    private func toggleSaved() async {
        do {
            // Update database
            try await AppDatabase.shared.writeAsync { db in
                var updatedEpisode = currentEpisode.episode
                try updatedEpisode.toggleSaved(db: db)
            }
            
            // Update local state
            await MainActor.run {
                isCurrentEpisodeSaved.toggle()
            }
            
            // Notify parent to reload episodes
            await MainActor.run {
                onEpisodeUpdated?()
            }
        } catch {
            print("Failed to toggle saved state: \(error)")
        }
    }
    
    private func prefetchAdjacentImages() async {
        var urlsToIdentifiers: [(url: String, identifier: String)] = []
        
        // Current episode image
        if let artworkURL = currentEpisode.episode.imageURL ?? currentEpisode.podcast.artworkURL {
            urlsToIdentifiers.append((artworkURL, currentEpisode.episode.uuid))
        }
        
        // Previous episode image
        if hasPrevious {
            let prevEpisode = episodes[currentIndex - 1]
            if let artworkURL = prevEpisode.episode.imageURL ?? prevEpisode.podcast.artworkURL {
                urlsToIdentifiers.append((artworkURL, prevEpisode.episode.uuid))
            }
        }
        
        // Next episode image
        if hasNext {
            let nextEpisode = episodes[currentIndex + 1]
            if let artworkURL = nextEpisode.episode.imageURL ?? nextEpisode.podcast.artworkURL {
                urlsToIdentifiers.append((artworkURL, nextEpisode.episode.uuid))
            }
        }
        
        await ArtworkCache.shared.prefetchBatch(urls: urlsToIdentifiers)
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
}

#Preview {
    let podcast = PodcastRecord(
        feedURL: "https://example.com/feed.xml",
        title: "Sample Podcast",
        author: "Sample Author",
        artworkColor: "#FF6B35"
    )
    
    let episode1 = EpisodeRecord(
        podcastId: 1,
        guid: "sample-guid-1",
        title: "Sample Episode 1",
        audioURL: "https://example.com/episode1.mp3",
        duration: 2847
    )
    
    let episode2 = EpisodeRecord(
        podcastId: 1,
        guid: "sample-guid-2",
        title: "Sample Episode 2",
        audioURL: "https://example.com/episode2.mp3",
        duration: 1847
    )
    
    let episodes = [
        EpisodeWithPodcast(episode: episode1, podcast: podcast),
        EpisodeWithPodcast(episode: episode2, podcast: podcast)
    ]
    
    PlayerView(episodes: episodes, startIndex: 0, onEpisodeUpdated: nil)
}
