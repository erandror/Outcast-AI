//
//  PlayerView.swift
//  Outcast
//
//  Created by Eran Dror on 11/28/25.
//

import SwiftUI
import GRDB

struct PlayerView: View {
    let startIndex: Int
    let initialFilter: ListenFilter
    let topicFilters: [SystemTagRecord]
    let autoPlay: Bool
    let onEpisodeUpdated: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playbackManager = PlaybackManager.shared
    @State private var showingPodcastDetail = false
    @State private var currentIndex: Int
    @State private var episodes: [EpisodeWithPodcast]
    @State private var selectedFilter: ListenFilter
    @State private var dragOffset: CGFloat = 0
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var isCurrentEpisodeSaved: Bool = false
    @State private var dragAxis: DragAxis? = nil
    @State private var isLoadingFilter = false
    @State private var previousFilterEpisodes: [EpisodeWithPodcast] = []
    @State private var nextFilterEpisodes: [EpisodeWithPodcast] = []
    @State private var showingUnfollowDialog = false
    @State private var pendingUnfollowPodcast: PodcastRecord?
    @State private var pendingUnfollowCount: Int = 0
    
    private enum DragAxis {
        case horizontal
        case vertical
    }
    
    init(episodes: [EpisodeWithPodcast], startIndex: Int, initialFilter: ListenFilter, topicFilters: [SystemTagRecord], autoPlay: Bool = true, onEpisodeUpdated: (() -> Void)? = nil) {
        self.startIndex = startIndex
        self.initialFilter = initialFilter
        self.topicFilters = topicFilters
        self.autoPlay = autoPlay
        self.onEpisodeUpdated = onEpisodeUpdated
        _currentIndex = State(initialValue: startIndex)
        _episodes = State(initialValue: episodes)
        _selectedFilter = State(initialValue: initialFilter)
    }
    
    /// Build the complete filter array: topics (sorted by popularity) + Up Next + mood filters
    private var allFilters: [ListenFilter] {
        var filters: [ListenFilter] = []
        
        // Add topic filters (reversed so most popular is closest to center)
        let sortedTopics = topicFilters.reversed()
        filters.append(contentsOf: sortedTopics.map { .topic($0) })
        
        // Add Up Next in the center
        filters.append(.standard(.upNext))
        
        // Add remaining mood/time filters (excluding upNext which is already added)
        let standardFilters = ForYouFilter.allCases.filter { $0 != .upNext }
        filters.append(contentsOf: standardFilters.map { .standard($0) })
        
        return filters
    }
    
    private var currentFilterIndex: Int? {
        allFilters.firstIndex(where: { $0.id == selectedFilter.id })
    }
    
    private var hasPreviousFilter: Bool {
        guard let index = currentFilterIndex else { return false }
        return index > 0
    }
    
    private var hasNextFilter: Bool {
        guard let index = currentFilterIndex else { return false }
        return index < allFilters.count - 1
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
                    // Previous filter content (to the left)
                    if hasPreviousFilter, let firstEpisode = previousFilterEpisodes.first {
                        episodeCard(for: firstEpisode, offset: 0)
                            .offset(x: -geometry.size.width + horizontalDragOffset)
                    }
                    
                    // Current filter content (vertical stack for episode navigation)
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
                    .offset(x: horizontalDragOffset)
                    
                    // Next filter content (to the right)
                    if hasNextFilter, let firstEpisode = nextFilterEpisodes.first {
                        episodeCard(for: firstEpisode, offset: 0)
                            .offset(x: geometry.size.width + horizontalDragOffset)
                    }
                }
                
                // Unified header with filter bar and close button
                VStack {
                    HStack(alignment: .center, spacing: 0) {
                        // Filter bar takes remaining space
                        ForYouFilterBar(
                            selectedFilter: $selectedFilter,
                            topicFilters: topicFilters
                        )
                        .onChange(of: selectedFilter) { _, newFilter in
                            Task {
                                await switchToFilter(newFilter)
                            }
                        }
                        
                        // Close button at right edge
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                        }
                        .padding(.trailing, 8)
                    }
                    
                    Spacer()
                }
                
                // Loading indicator overlay
                if isLoadingFilter {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !isAnimating && !isLoadingFilter else { return }
                        
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        
                        // Determine axis lock on first significant movement
                        if dragAxis == nil {
                            let threshold: CGFloat = 20
                            if abs(horizontal) > threshold || abs(vertical) > threshold {
                                dragAxis = abs(horizontal) > abs(vertical) ? .horizontal : .vertical
                            }
                        }
                        
                        // Handle based on locked axis
                        if dragAxis == .horizontal {
                            // Horizontal swipe for filter switching
                            if horizontal < 0 && hasNextFilter {
                                // Swiping left to next filter
                                horizontalDragOffset = horizontal
                            } else if horizontal > 0 && hasPreviousFilter {
                                // Swiping right to previous filter
                                horizontalDragOffset = horizontal
                            } else if (horizontal < 0 && !hasNextFilter) || (horizontal > 0 && !hasPreviousFilter) {
                                // Resistance at boundaries
                                horizontalDragOffset = horizontal * 0.2
                            }
                        } else if dragAxis == .vertical {
                            // Vertical swipe for episode navigation (existing behavior)
                            if vertical < 0 && hasNext {
                                // Dragging up to next episode
                                dragOffset = vertical
                            } else if vertical > 0 && hasPrevious {
                                // Dragging down to previous episode
                                dragOffset = vertical
                            } else if (vertical < 0 && !hasNext) || (vertical > 0 && !hasPrevious) {
                                // Resistance at boundaries
                                dragOffset = vertical * 0.2
                            }
                        }
                    }
                    .onEnded { value in
                        guard !isAnimating && !isLoadingFilter else { return }
                        
                        let threshold: CGFloat = 100
                        
                        if dragAxis == .horizontal {
                            let horizontal = value.translation.width
                            
                            if horizontal < -threshold && hasNextFilter {
                                // Swipe left - go to next filter
                                Task {
                                    await goToNextFilter()
                                }
                            } else if horizontal > threshold && hasPreviousFilter {
                                // Swipe right - go to previous filter
                                Task {
                                    await goToPreviousFilter()
                                }
                            } else {
                                // Snap back
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    horizontalDragOffset = 0
                                }
                            }
                        } else if dragAxis == .vertical {
                            let vertical = value.translation.height
                            
                            if vertical < -threshold && hasNext {
                                // Swipe up - go to next episode
                                goToNext(screenHeight: geometry.size.height)
                            } else if vertical > threshold && hasPrevious {
                                // Swipe down - go to previous episode
                                goToPrevious(screenHeight: geometry.size.height)
                            } else {
                                // Snap back to current
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                            }
                        }
                        
                        // Reset axis lock
                        dragAxis = nil
                    }
            )
        }
        .task {
            // Set playback context in PlaybackManager
            playbackManager.setPlaybackContext(
                filter: initialFilter,
                episodes: episodes,
                currentIndex: currentIndex
            )
            
            // Load episode into playback manager and start playing
            await loadCurrentEpisode()
            // Prefetch adjacent episode images
            await prefetchAdjacentImages()
            // Prefetch adjacent filter episodes
            await prefetchAdjacentFilters()
        }
        .sheet(isPresented: $showingPodcastDetail) {
            NavigationStack {
                ShowView(podcast: currentEpisode.podcast)
            }
        }
        .sheet(isPresented: $showingUnfollowDialog) {
            if let podcast = pendingUnfollowPodcast {
                UnfollowDialog(
                    podcast: podcast,
                    downvoteCount: pendingUnfollowCount,
                    onRemoveFromUpNext: {
                        Task {
                            await removeFromUpNext(podcast: podcast)
                        }
                    },
                    onUnfollow: {
                        Task {
                            await unfollowPodcast(podcast: podcast)
                        }
                    },
                    onKeep: {
                        Task {
                            await skipToNextOrDismiss()
                        }
                    }
                )
                .presentationDetents([.large])
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
            
            // Update playback context index
            playbackManager.updatePlaybackContextIndex(currentIndex)
            
            // Load new episode and prefetch adjacent images
            // Preserve current playing state when swiping
            Task {
                await loadCurrentEpisode(autoPlay: playbackManager.isPlaying)
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
            
            // Update playback context index
            playbackManager.updatePlaybackContextIndex(currentIndex)
            
            // Load new episode and prefetch adjacent images
            // Preserve current playing state when swiping
            Task {
                await loadCurrentEpisode(autoPlay: playbackManager.isPlaying)
                await prefetchAdjacentImages()
            }
        }
    }
    
    private func goToNextFilter() async {
        guard let currentIndex = currentFilterIndex, hasNextFilter else {
            // Snap back if no next filter
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    horizontalDragOffset = 0
                }
            }
            return
        }
        
        let nextFilter = allFilters[currentIndex + 1]
        let screenWidth = UIScreen.main.bounds.width
        
        await MainActor.run {
            isAnimating = true
            
            // Animate slide left to next filter
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                horizontalDragOffset = -screenWidth
            }
        }
        
        // Load new filter content after animation completes
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        await switchToFilterWithoutAnimation(nextFilter)
    }
    
    private func goToPreviousFilter() async {
        guard let currentIndex = currentFilterIndex, hasPreviousFilter else {
            // Snap back if no previous filter
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    horizontalDragOffset = 0
                }
            }
            return
        }
        
        let previousFilter = allFilters[currentIndex - 1]
        let screenWidth = UIScreen.main.bounds.width
        
        await MainActor.run {
            isAnimating = true
            
            // Animate slide right to previous filter
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                horizontalDragOffset = screenWidth
            }
        }
        
        // Load new filter content after animation completes
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        await switchToFilterWithoutAnimation(previousFilter)
    }
    
    private func switchToFilter(_ newFilter: ListenFilter) async {
        guard newFilter.id != selectedFilter.id else { return }
        
        // Determine swipe direction based on filter position
        guard let currentIdx = currentFilterIndex,
              let newIdx = allFilters.firstIndex(where: { $0.id == newFilter.id }) else {
            // If we can't determine direction, just switch instantly
            await switchToFilterWithoutAnimation(newFilter)
            return
        }
        
        let screenWidth = UIScreen.main.bounds.width
        
        await MainActor.run {
            isAnimating = true
            
            // Animate in the direction of the filter change
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if newIdx > currentIdx {
                    // Swiping to next (left)
                    horizontalDragOffset = -screenWidth
                } else {
                    // Swiping to previous (right)
                    horizontalDragOffset = screenWidth
                }
            }
        }
        
        // Load new filter content after animation completes
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        await switchToFilterWithoutAnimation(newFilter)
    }
    
    private func switchToFilterWithoutAnimation(_ newFilter: ListenFilter) async {
        guard newFilter.id != selectedFilter.id else {
            // Just reset if it's the same filter
            await MainActor.run {
                horizontalDragOffset = 0
                isAnimating = false
            }
            return
        }
        
        do {
            // Load episodes for the new filter
            let newEpisodes = try await AppDatabase.shared.readAsync { db in
                try EpisodeWithPodcast.fetchFiltered(filter: newFilter, limit: 50, offset: 0, db: db)
            }
            
            // Only switch if there are episodes available
            guard !newEpisodes.isEmpty else {
                print("No episodes available for filter: \(newFilter.label)")
                await MainActor.run {
                    // Snap back horizontal drag
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        horizontalDragOffset = 0
                    }
                    isAnimating = false
                }
                return
            }
            
            await MainActor.run {
                // Update filter and episodes
                selectedFilter = newFilter
                episodes = newEpisodes
                currentIndex = 0
                
                // Update playback context with new filter and episodes
                playbackManager.updatePlaybackContextEpisodes(newEpisodes, newIndex: 0)
                
                // Reset drag offsets
                dragOffset = 0
                horizontalDragOffset = 0
                
                isAnimating = false
            }
            
            // Load the first episode and prefetch images
            // Preserve current playing state when switching filters
            await loadCurrentEpisode(autoPlay: playbackManager.isPlaying)
            await prefetchAdjacentImages()
            await prefetchAdjacentFilters()
            
        } catch {
            print("Failed to load episodes for filter: \(error)")
            await MainActor.run {
                // Snap back horizontal drag
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    horizontalDragOffset = 0
                }
                isAnimating = false
            }
        }
    }
    
    @ViewBuilder
    private func episodeCard(for episode: EpisodeWithPodcast, offset: CGFloat) -> some View {
        VStack(spacing: 32) {
            // Top spacer with minimum height to avoid header overlap
            Spacer()
                .frame(minHeight: 56)
            
            // Artwork - slightly smaller to ensure full visibility
            EpisodeArtwork(
                episode: episode.episode,
                podcast: episode.podcast,
                size: .large
            )
            .frame(width: 260, height: 260)
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
            HStack {
                Button {
                    Task {
                        await thumbsDown()
                    }
                } label: {
                    Image(systemName: "hand.thumbsdown")
                        .font(.title)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await playbackManager.skipBackward(by: 15)
                    }
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Button {
                    playbackManager.togglePlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await playbackManager.skipForward(by: 30)
                    }
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.title)
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
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
            .padding(.horizontal, 32)
            
            // Bottom spacer
            Spacer()
        }
        .offset(y: offset)
    }
    
    private func loadCurrentEpisode(autoPlay: Bool? = nil) async {
        do {
            let shouldAutoPlay = autoPlay ?? self.autoPlay
            try await playbackManager.load(episode: currentEpisode.episode, autoPlay: shouldAutoPlay)
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
    
    private func prefetchAdjacentFilters() async {
        guard let currentIdx = currentFilterIndex else { return }
        
        var artworkUrlsToIdentifiers: [(url: String, identifier: String)] = []
        
        // Prefetch previous filter's first episode
        if currentIdx > 0 {
            let prevFilter = allFilters[currentIdx - 1]
            do {
                let prevEpisodes = try await AppDatabase.shared.readAsync { db in
                    try EpisodeWithPodcast.fetchFiltered(filter: prevFilter, limit: 1, offset: 0, db: db)
                }
                
                await MainActor.run {
                    previousFilterEpisodes = prevEpisodes
                }
                
                // Prefetch artwork for previous filter's first episode
                if let firstEpisode = prevEpisodes.first,
                   let artworkURL = firstEpisode.episode.imageURL ?? firstEpisode.podcast.artworkURL {
                    artworkUrlsToIdentifiers.append((artworkURL, firstEpisode.episode.uuid))
                }
            } catch {
                print("Failed to prefetch previous filter episodes: \(error)")
                await MainActor.run {
                    previousFilterEpisodes = []
                }
            }
        } else {
            await MainActor.run {
                previousFilterEpisodes = []
            }
        }
        
        // Prefetch next filter's first episode
        if currentIdx < allFilters.count - 1 {
            let nextFilter = allFilters[currentIdx + 1]
            do {
                let nextEpisodes = try await AppDatabase.shared.readAsync { db in
                    try EpisodeWithPodcast.fetchFiltered(filter: nextFilter, limit: 1, offset: 0, db: db)
                }
                
                await MainActor.run {
                    nextFilterEpisodes = nextEpisodes
                }
                
                // Prefetch artwork for next filter's first episode
                if let firstEpisode = nextEpisodes.first,
                   let artworkURL = firstEpisode.episode.imageURL ?? firstEpisode.podcast.artworkURL {
                    artworkUrlsToIdentifiers.append((artworkURL, firstEpisode.episode.uuid))
                }
            } catch {
                print("Failed to prefetch next filter episodes: \(error)")
                await MainActor.run {
                    nextFilterEpisodes = []
                }
            }
        } else {
            await MainActor.run {
                nextFilterEpisodes = []
            }
        }
        
        // Prefetch all collected artwork URLs
        if !artworkUrlsToIdentifiers.isEmpty {
            await ArtworkCache.shared.prefetchBatch(urls: artworkUrlsToIdentifiers)
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
    
    // MARK: - Thumbs Down
    
    private func thumbsDown() async {
        do {
            // Mark episode as downvoted
            try await AppDatabase.shared.writeAsync { db in
                var updatedEpisode = currentEpisode.episode
                try updatedEpisode.markDownvoted(db: db)
            }
            
            // Count downvoted episodes for this podcast
            let downvoteCount = try await AppDatabase.shared.readAsync { db in
                try EpisodeRecord.countDownvotedForPodcast(podcastId: currentEpisode.podcast.id!, db: db)
            }
            
            // If 2 or more downvotes, show unfollow dialog
            if downvoteCount >= 2 {
                await MainActor.run {
                    pendingUnfollowPodcast = currentEpisode.podcast
                    pendingUnfollowCount = downvoteCount
                    showingUnfollowDialog = true
                }
            } else {
                // Otherwise, just skip to next
                await skipToNextOrDismiss()
            }
            
            // Notify parent to reload episodes (to remove from lists)
            await MainActor.run {
                onEpisodeUpdated?()
            }
        } catch {
            print("Failed to downvote episode: \(error)")
        }
    }
    
    private func skipToNextOrDismiss() async {
        await MainActor.run {
            if hasNext {
                // Skip to next episode
                let screenHeight = UIScreen.main.bounds.height
                goToNext(screenHeight: screenHeight)
            } else {
                // No more episodes, dismiss player
                dismiss()
            }
        }
    }
    
    private func removeFromUpNext(podcast: PodcastRecord) async {
        do {
            try await AppDatabase.shared.writeAsync { db in
                var updatedPodcast = podcast
                updatedPodcast.isUpNext = false
                try updatedPodcast.update(db)
            }
            
            // Skip to next episode or dismiss
            await skipToNextOrDismiss()
        } catch {
            print("Failed to remove podcast from Up Next: \(error)")
        }
    }
    
    private func unfollowPodcast(podcast: PodcastRecord) async {
        do {
            try await AppDatabase.shared.writeAsync { db in
                try podcast.deleteWithEpisodes(db: db)
            }
            
            // Dismiss the player since we unfollowed
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("Failed to unfollow podcast: \(error)")
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
    
    PlayerView(
        episodes: episodes,
        startIndex: 0,
        initialFilter: .standard(.upNext),
        topicFilters: [],
        autoPlay: true,
        onEpisodeUpdated: nil
    )
}
