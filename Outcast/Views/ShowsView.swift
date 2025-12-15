//
//  ShowsView.swift
//  Outcast
//
//  Grid view showing all subscribed podcasts
//

import SwiftUI
import GRDB

struct ShowsView: View {
    let onSelectPodcast: (PodcastRecord) -> Void
    
    @State private var podcasts: [PodcastRecord] = []
    @State private var isLoading = true
    
    // Adaptive columns: 2 on iPhone, 3 on iPad
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if podcasts.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(podcasts) { podcast in
                            PodcastGridCell(
                                podcast: podcast,
                                onTap: {
                                    onSelectPodcast(podcast)
                                },
                                onToggleUpNext: {
                                    Task {
                                        await toggleUpNext(for: podcast)
                                    }
                                }
                            )
                        }
                    }
                    .padding(20)
                }
            }
        }
        .task {
            await loadPodcasts()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No Podcasts Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text("Subscribe to podcasts to see them here.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadPodcasts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loaded = try await AppDatabase.shared.readAsync { db in
                try PodcastRecord.fetchAllOrderedByTitle(db: db)
            }
            
            await MainActor.run {
                podcasts = loaded
            }
        } catch {
            print("Failed to load podcasts: \(error)")
        }
    }
    
    private func toggleUpNext(for podcast: PodcastRecord) async {
        do {
            // Toggle in database
            try await AppDatabase.shared.writeAsync { db in
                var updatedPodcast = podcast
                updatedPodcast.isUpNext.toggle()
                try updatedPodcast.update(db)
            }
            
            // Reload podcasts to reflect the change
            await loadPodcasts()
        } catch {
            print("Failed to toggle Up Next: \(error)")
        }
    }
}

// MARK: - Podcast Grid Cell

private struct PodcastGridCell: View {
    let podcast: PodcastRecord
    let onTap: () -> Void
    let onToggleUpNext: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Artwork with Up Next badge overlay
            Button(action: onTap) {
                ZStack(alignment: .bottomTrailing) {
                    // Artwork
                    if let artworkURL = podcast.artworkURL,
                       let url = URL(string: artworkURL) {
                        CachedAsyncImage(
                            url: url,
                            content: { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            },
                            placeholder: {
                                artworkPlaceholder
                            }
                        )
                    } else {
                        artworkPlaceholder
                    }
                    
                    // Up Next badge overlay
                    upNextBadge
                        .padding(8)
                }
                .frame(width: 150, height: 150)
                .cornerRadius(8)
                .clipped()
            }
            .buttonStyle(.plain)
            
            // Podcast title
            Text(podcast.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var artworkPlaceholder: some View {
        ZStack {
            Color(hexString: podcast.artworkColor ?? "#4ECDC4")
            Text(String(podcast.title.prefix(1)))
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    private var upNextBadge: some View {
        Button(action: onToggleUpNext) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 32, height: 32)
                
                Image(systemName: podcast.isUpNext ? "text.badge.checkmark" : "text.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(podcast.isUpNext ? .green : .white)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ShowsView(onSelectPodcast: { _ in })
}

