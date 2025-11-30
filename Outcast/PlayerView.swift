//
//  PlayerView.swift
//  Outcast
//
//  Created by Eran Dror on 11/28/25.
//

import SwiftUI

struct PlayerView: View {
    let episodes: [EpisodeWithPodcast]
    let startIndex: Int
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playbackManager = PlaybackManager.shared
    @State private var showingPodcastDetail = false
    @State private var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating = false
    
    init(episodes: [EpisodeWithPodcast], startIndex: Int) {
        self.episodes = episodes
        self.startIndex = startIndex
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
                            goToNext()
                        } else if translation > threshold && hasPrevious {
                            // Swipe down - go to previous
                            goToPrevious()
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
    
    private func goToNext() {
        guard hasNext && !isAnimating else { return }
        
        isAnimating = true
        
        // Animate slide up to next episode
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dragOffset = -UIScreen.main.bounds.height
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
    
    private func goToPrevious() {
        guard hasPrevious && !isAnimating else { return }
        
        isAnimating = true
        
        // Animate slide down to previous episode
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dragOffset = UIScreen.main.bounds.height
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
            ZStack {
                if let artworkURL = episode.episode.imageURL ?? episode.podcast.artworkURL,
                   let url = URL(string: artworkURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        artworkPlaceholder(for: episode)
                    }
                } else {
                    artworkPlaceholder(for: episode)
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
            }
            
            // Bottom spacer
            Spacer()
        }
        .offset(y: offset)
    }
    
    private func artworkPlaceholder(for episode: EpisodeWithPodcast) -> some View {
        ZStack {
            Color(hexString: episode.podcast.artworkColor ?? "#4ECDC4")
            Text(String(episode.podcast.title.prefix(1)))
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    private func loadCurrentEpisode() async {
        do {
            try await playbackManager.load(episode: currentEpisode.episode, autoPlay: true)
        } catch {
            print("Failed to load episode: \(error)")
        }
    }
    
    private func prefetchAdjacentImages() async {
        var urlsToPrefetch: [String] = []
        
        // Current episode image
        if let artworkURL = currentEpisode.episode.imageURL ?? currentEpisode.podcast.artworkURL {
            urlsToPrefetch.append(artworkURL)
        }
        
        // Previous episode image
        if hasPrevious {
            let prevEpisode = episodes[currentIndex - 1]
            if let artworkURL = prevEpisode.episode.imageURL ?? prevEpisode.podcast.artworkURL {
                urlsToPrefetch.append(artworkURL)
            }
        }
        
        // Next episode image
        if hasNext {
            let nextEpisode = episodes[currentIndex + 1]
            if let artworkURL = nextEpisode.episode.imageURL ?? nextEpisode.podcast.artworkURL {
                urlsToPrefetch.append(artworkURL)
            }
        }
        
        await ImageCache.shared.prefetchBatch(urlsToPrefetch)
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
    
    PlayerView(episodes: episodes, startIndex: 0)
}
