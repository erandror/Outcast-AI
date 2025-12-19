//
//  EpisodeView.swift
//  Outcast
//
//  Dedicated episode detail screen with show notes and actions
//

import SwiftUI
import GRDB

struct EpisodeView: View {
    let episodes: [EpisodeWithPodcast]
    let startIndex: Int
    let onEpisodeUpdated: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var showPlayer = false
    @State private var showPodcastDetail = false
    @State private var playbackProgress: Double = 0
    @State private var isSaved: Bool = false
    @ObservedObject private var playbackManager = PlaybackManager.shared
    
    private var episode: EpisodeWithPodcast {
        episodes[startIndex]
    }
    
    var body: some View {
        ZStack {
            // Stark black background
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header with close button
                    headerView
                    
                    // Artwork
                    artworkSection
                        .padding(.top, 20)
                    
                    // Episode info
                    episodeInfoSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    
                    // Action buttons with Liquid Glass
                    actionButtonsSection
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                    
                    // Show notes
                    showNotesSection
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                }
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            calculateProgress()
            isSaved = episode.episode.isSaved
        }
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(episodes: episodes, startIndex: startIndex, onEpisodeUpdated: onEpisodeUpdated)
        }
        .sheet(isPresented: $showPodcastDetail) {
            NavigationStack {
                ShowView(podcast: episode.podcast)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button {
                    // Share action
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                
                Button {
                    // Star/favorite action
                } label: {
                    Image(systemName: "star")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Artwork
    
    private var artworkSection: some View {
        EpisodeArtwork(
            episode: episode.episode,
            podcast: episode.podcast,
            size: .large
        )
        .frame(width: 280, height: 280)
        .shadow(color: .white.opacity(0.1), radius: 20)
    }
    
    // MARK: - Episode Info
    
    private var episodeInfoSection: some View {
        VStack(spacing: 12) {
            // Episode title
            Text(episode.episode.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            // Podcast name (tappable)
            Button {
                showPodcastDetail = true
            } label: {
                Text(episode.podcast.title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            // Metadata row
            HStack(spacing: 8) {
                if let date = episode.episode.publishedDate {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                if episode.episode.publishedDate != nil && episode.episode.duration != nil {
                    Text("•")
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                if let duration = episode.episode.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.top, 4)
            
            // Progress bar (if in progress)
            if episode.episode.playingStatus == .inProgress {
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                            
                            // Progress
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geometry.size.width * playbackProgress)
                        }
                    }
                    .frame(height: 3)
                    .cornerRadius(1.5)
                    
                    Text(episode.episode.remainingTimeFormatted ?? "")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Action Buttons (Liquid Glass)
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Primary action: Play/Resume
            Button {
                showPlayer = true
            } label: {
                HStack {
                    Image(systemName: playButtonIcon)
                        .font(.title3)
                    Text(playButtonText)
                        .font(.headline)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.white)
                .cornerRadius(12)
            }
            
            // Secondary actions grid
            HStack(spacing: 12) {
                // Download button
                actionButton(
                    icon: downloadButtonIcon,
                    title: downloadButtonText,
                    action: { downloadAction() }
                )
                
                // Mark as played button
                actionButton(
                    icon: playedButtonIcon,
                    title: playedButtonText,
                    action: { markPlayedAction() }
                )
            }
            
            HStack(spacing: 12) {
                // Save for later button
                actionButton(
                    icon: isSaved ? "bookmark.fill" : "bookmark",
                    title: isSaved ? "Saved" : "Save for Later",
                    action: { toggleSaveAction() }
                )
                
                // Archive button
                actionButton(
                    icon: "archivebox",
                    title: "Archive",
                    action: { archiveAction() }
                )
            }
        }
    }
    
    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Show Notes
    
    private var showNotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Show Notes")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            if let description = episode.episode.episodeDescription, !description.isEmpty {
                ShowNotesView(
                    htmlContent: description,
                    tintColor: .white
                )
                .frame(minHeight: 200)
            } else {
                Text("No show notes available.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var playButtonIcon: String {
        switch episode.episode.playingStatus {
        case .notPlayed:
            return "play.fill"
        case .inProgress:
            return "play.fill"
        case .completed:
            return "arrow.counterclockwise"
        }
    }
    
    private var playButtonText: String {
        switch episode.episode.playingStatus {
        case .notPlayed:
            return "Play Episode"
        case .inProgress:
            return "Resume Episode"
        case .completed:
            return "Play Again"
        }
    }
    
    private var downloadButtonIcon: String {
        episode.episode.isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle"
    }
    
    private var downloadButtonText: String {
        episode.episode.isDownloaded ? "Downloaded" : "Download"
    }
    
    private var playedButtonIcon: String {
        episode.episode.playingStatus == .completed ? "circle" : "checkmark.circle"
    }
    
    private var playedButtonText: String {
        episode.episode.playingStatus == .completed ? "Mark Unplayed" : "Mark Played"
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func calculateProgress() {
        guard let duration = episode.episode.duration, duration > 0 else {
            playbackProgress = 0
            return
        }
        playbackProgress = episode.episode.playedUpTo / duration
    }
    
    // MARK: - Actions
    
    private func downloadAction() {
        // TODO: Implement download functionality
        print("Download action")
    }
    
    private func markPlayedAction() {
        Task {
            do {
                let episodeToUpdate = episode.episode
                try await AppDatabase.shared.writeAsync { db in
                    var updatedEpisode = episodeToUpdate
                    if updatedEpisode.playingStatus == .completed {
                        updatedEpisode.playingStatus = .notPlayed
                        updatedEpisode.playedUpTo = 0
                    } else {
                        try updatedEpisode.markAsCompleted(db: db)
                    }
                }
            } catch {
                print("Failed to update play status: \(error)")
            }
        }
    }
    
    private func toggleSaveAction() {
        Task {
            do {
                try await AppDatabase.shared.writeAsync { db in
                    var updatedEpisode = episode.episode
                    try updatedEpisode.toggleSaved(db: db)
                }
                
                await MainActor.run {
                    isSaved.toggle()
                }
                
                // Notify parent to reload episodes
                await MainActor.run {
                    onEpisodeUpdated?()
                }
            } catch {
                print("Failed to toggle saved state: \(error)")
            }
        }
    }
    
    private func archiveAction() {
        // TODO: Implement archive functionality
        print("Archive action")
    }
}

#Preview {
    let podcast = PodcastRecord(
        feedURL: "https://example.com/feed.xml",
        title: "Sample Podcast",
        author: "Sample Author",
        podcastDescription: "A great podcast about interesting topics.",
        artworkColor: "#FF6B35"
    )
    
    let episode = EpisodeRecord(
        podcastId: 1,
        guid: "sample-guid",
        title: "Episode 42: The Answer to Everything",
        episodeDescription: """
        <h2>Episode Description</h2>
        <p>This is a <strong>sample episode</strong> description with <em>HTML formatting</em>.</p>
        <p>It includes:</p>
        <ul>
            <li>Bullet points</li>
            <li>Links like <a href="https://example.com">this one</a></li>
            <li>And other HTML elements</li>
        </ul>
        <blockquote>Here's a quote from the episode.</blockquote>
        """,
        audioURL: "https://example.com/episode.mp3",
        duration: 2847,
        publishedDate: Date().addingTimeInterval(-86400 * 3),
        playedUpTo: 500,
        playingStatus: .inProgress
    )
    
    EpisodeView(episodes: [EpisodeWithPodcast(episode: episode, podcast: podcast)], startIndex: 0, onEpisodeUpdated: nil)
}
