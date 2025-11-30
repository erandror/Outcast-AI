//
//  DownloadsListView.swift
//  Outcast
//
//  List view for managing downloads
//

import SwiftUI
import GRDB

/// View for managing all downloads
struct DownloadsListView: View {
    @State private var downloadedEpisodes: [EpisodeRecord] = []
    @State private var downloadingEpisodes: [EpisodeRecord] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !downloadingEpisodes.isEmpty {
                        downloadingSection
                    }
                    
                    if !downloadedEpisodes.isEmpty {
                        downloadedSection
                    }
                    
                    if downloadedEpisodes.isEmpty && downloadingEpisodes.isEmpty && !isLoading {
                        emptyState
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadDownloads()
        }
        .refreshable {
            await loadDownloads()
        }
    }
    
    private var downloadingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Downloading")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            ForEach(downloadingEpisodes) { episode in
                DownloadProgressView(episode: episode)
            }
        }
    }
    
    private var downloadedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Downloaded")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                if !downloadedEpisodes.isEmpty {
                    Text("\(downloadedEpisodes.count) episodes")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            ForEach(downloadedEpisodes) { episode in
                DownloadedEpisodeRow(episode: episode)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Downloads")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("Downloaded episodes will appear here")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    private func loadDownloads() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let db = AppDatabase.shared
            
            downloadingEpisodes = try await db.readAsync { db in
                try EpisodeRecord.fetchDownloading(db: db)
            }
            
            downloadedEpisodes = try await db.readAsync { db in
                try EpisodeRecord.fetchDownloaded(db: db)
            }
        } catch {
            print("Failed to load downloads: \(error)")
        }
    }
}

/// Row for a downloaded episode
struct DownloadedEpisodeRow: View {
    let episode: EpisodeRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // Placeholder for artwork
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "waveform")
                        .foregroundColor(.white.opacity(0.5))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if let duration = episode.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let fileSize = episode.downloadedFileSize {
                    Text(formatBytes(fileSize))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            DownloadButton(episode: episode)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    NavigationStack {
        DownloadsListView()
    }
}
