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
    
    let onPlayEpisode: (PlaybackContext) -> Void
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
                            EpisodeListRow(
                                episode: episode,
                                variant: .history,
                                onPlay: {
                                    // Create playback context with history episodes
                                    if let index = historyEpisodes.firstIndex(where: { $0.id == episode.id }) {
                                        let context = PlaybackContext(
                                            filter: .standard(.latest),  // History doesn't have a specific filter
                                            episodes: historyEpisodes,
                                            currentIndex: index
                                        )
                                        onPlayEpisode(context)
                                    }
                                },
                                onTapEpisode: {
                                    onTapEpisode(episode)
                                },
                                onToggleUpNext: {
                                    Task {
                                        await toggleUpNext(for: episode)
                                    }
                                },
                                onToggleSave: {
                                    Task {
                                        await toggleSaved(for: episode)
                                    }
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
    
    private func toggleUpNext(for episode: EpisodeWithPodcast) async {
        do {
            try await AppDatabase.shared.writeAsync { db in
                var podcast = episode.podcast
                podcast.isUpNext.toggle()
                try podcast.update(db)
            }
            await loadHistory()
        } catch {
            print("Failed to toggle up next: \(error)")
        }
    }
    
    private func toggleSaved(for episode: EpisodeWithPodcast) async {
        do {
            try await AppDatabase.shared.writeAsync { db in
                var ep = episode.episode
                try ep.toggleSaved(db: db)
            }
            await loadHistory()
        } catch {
            print("Failed to toggle saved: \(error)")
        }
    }
}

// MARK: - Previews

#Preview {
    HistoryView(
        onPlayEpisode: { context in },
        onTapEpisode: { _ in }
    )
    .background(Color.black)
}
