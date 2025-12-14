//
//  MiniPlayer.swift
//  Outcast
//
//  Compact mini player bar for current episode
//

import SwiftUI

struct MiniPlayer: View {
    @ObservedObject private var playbackManager = PlaybackManager.shared
    var onTap: (() -> Void)?
    
    var body: some View {
        if let episode = playbackManager.currentEpisode,
           let podcast = playbackManager.currentPodcast {
            HStack(spacing: 12) {
                // Artwork
                if let artworkURL = podcast.artworkURL,
                   let url = URL(string: artworkURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(4)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .cornerRadius(4)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundStyle(.white.opacity(0.3))
                        )
                }
                
                // Episode info
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(podcast.title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Play/Pause button
                Button {
                    playbackManager.togglePlayPause()
                } label: {
                    Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 8)
            .background(
                Color.black.opacity(0.95)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1),
                        alignment: .top
                    )
            )
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
        }
    }
}

#Preview {
    MiniPlayer(onTap: {
        print("Mini player tapped")
    })
}
