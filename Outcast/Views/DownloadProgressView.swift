//
//  DownloadProgressView.swift
//  Outcast
//
//  Display download progress details
//

import SwiftUI

/// Detailed progress view for downloads
struct DownloadProgressView: View {
    let episode: EpisodeRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(episode.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Spacer()
                
                if episode.downloadStatus == .downloading {
                    Text("\(Int(episode.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            if episode.downloadStatus == .downloading || episode.downloadStatus == .queued {
                ProgressView(value: episode.downloadProgress)
                    .tint(.white)
                
                HStack {
                    if episode.downloadStatus == .downloading {
                        Text("Downloading...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("Waiting...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    if let fileSize = episode.fileSize {
                        Text(formatBytes(fileSize))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } else if episode.downloadStatus == .failed {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(episode.downloadError ?? "Download failed")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
