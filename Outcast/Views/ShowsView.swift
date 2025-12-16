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
    @State private var selectedFilter: ShowsFilter = .allShows
    @State private var gridRefreshID = UUID()
    
    // Adaptive columns: 2 on iPhone, 3 on iPad
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 20)
    ]
    
    // Filter podcasts based on selected filter
    private var filteredPodcasts: [PodcastRecord] {
        switch selectedFilter {
        case .allShows:
            return podcasts
        case .upNext:
            return podcasts.filter { $0.isUpNext }
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if podcasts.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    // Filter bar
                    ShowsFilterBar(selectedFilter: $selectedFilter)
                    
                    // Podcasts grid
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(filteredPodcasts) { podcast in
                                PodcastGridCell(
                                    podcast: podcast,
                                    onTap: {
                                        onSelectPodcast(podcast)
                                    },
                                    onToggleUpNext: {
                                        toggleUpNext(for: podcast)
                                    }
                                )
                            }
                        }
                        .padding(20)
                        .id(gridRefreshID) // Force grid re-render when toggling
                    }
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
    
    @MainActor
    private func toggleUpNext(for podcast: PodcastRecord) {
        // OPTIMISTIC UPDATE: Update UI first, then persist to database
        guard let index = podcasts.firstIndex(where: { $0.uuid == podcast.uuid }) else { return }
        
        let newValue = !podcasts[index].isUpNext
        
        // Update UI immediately - use explicit array replacement to trigger @State
        var updatedPodcast = podcasts[index]
        updatedPodcast.isUpNext = newValue
        podcasts.remove(at: index)
        podcasts.insert(updatedPodcast, at: index)
        
        // Force ForEach to re-iterate by changing grid identity
        gridRefreshID = UUID()
        
        // Persist to database in background (fire and forget)
        let podcastUUID = podcast.uuid
        Task.detached {
            do {
                try await AppDatabase.shared.writeAsync { db in
                    if var dbPodcast = try PodcastRecord.fetchByUUID(podcastUUID, db: db) {
                        dbPodcast.isUpNext = newValue
                        try dbPodcast.update(db)
                    }
                }
            } catch {
                print("Failed to persist Up Next toggle: \(error)")
            }
        }
    }
}

// MARK: - Shows Filter Bar

private struct ShowsFilterBar: View {
    @Binding var selectedFilter: ShowsFilter
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(ShowsFilter.allCases, id: \.self) { filter in
                FilterTab(
                    filter: filter,
                    isSelected: selectedFilter == filter
                ) {
                    selectedFilter = filter
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black)
    }
}

private struct FilterTab: View {
    let filter: ShowsFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(filter.emoji)
                    .font(.system(size: 16))
                
                Text(filter.label)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
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
                    PodcastArtwork(podcast: podcast, size: .medium)
                    
                    // Up Next badge overlay
                    upNextBadge
                        .padding(8)
                }
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
