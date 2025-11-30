//
//  DownloadButton.swift
//  Outcast
//
//  Context-aware download button for episodes
//

import SwiftUI

/// Download button with context-aware states
struct DownloadButton: View {
    let episode: EpisodeRecord
    @State private var isProcessing = false
    
    var body: some View {
        Button(action: handleTap) {
            downloadIcon
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
        }
        .disabled(isProcessing)
    }
    
    @ViewBuilder
    private var downloadIcon: some View {
        switch episode.downloadStatus {
        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
        case .queued:
            Image(systemName: "clock")
        case .downloading:
            DownloadProgressRing(progress: episode.downloadProgress)
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
        case .failed:
            Image(systemName: "exclamationmark.circle")
        case .paused:
            Image(systemName: "pause.circle")
        }
    }
    
    private func handleTap() {
        isProcessing = true
        Task {
            defer { isProcessing = false }
            
            switch episode.downloadStatus {
            case .notDownloaded, .failed, .paused:
                // Start download
                try? await DownloadManager.shared.downloadEpisode(
                    episodeUUID: episode.uuid,
                    url: episode.audioURL,
                    mimeType: episode.audioMimeType,
                    allowCellular: false
                )
            case .queued, .downloading:
                // Cancel download
                try? await DownloadManager.shared.cancelDownload(episodeUUID: episode.uuid)
            case .downloaded:
                // Delete download
                let fileExtension = await FileStorageManager.shared.fileExtension(
                    from: episode.audioMimeType,
                    or: episode.audioURL
                )
                try? await DownloadManager.shared.deleteDownload(
                    episodeUUID: episode.uuid,
                    fileExtension: fileExtension
                )
            }
        }
    }
}

/// Progress ring for download
struct DownloadProgressRing: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, lineWidth: 2)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)
        }
        .frame(width: 18, height: 18)
    }
}
