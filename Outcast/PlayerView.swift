//
//  PlayerView.swift
//  Outcast
//
//  Created by Eran Dror on 11/28/25.
//

import SwiftUI
import SwiftData

struct PlayerView: View {
    let episode: Episode
    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    
    var body: some View {
        ZStack {
            // Stark black background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Close button
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
                
                // Artwork placeholder
                ZStack {
                    Color(hex: episode.artworkColor)
                    Text(String(episode.podcastTitle.prefix(1)))
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 280, height: 280)
                .cornerRadius(8)
                .shadow(color: .white.opacity(0.1), radius: 20)
                
                // Episode info
                VStack(spacing: 8) {
                    Text(episode.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(episode.podcastTitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 32)
                
                // Progress slider
                VStack(spacing: 8) {
                    Slider(value: $currentTime, in: 0...episode.duration)
                        .tint(.white)
                        .padding(.horizontal, 32)
                    
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(formatTime(episode.duration))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 40)
                }
                
                // Playback controls
                HStack(spacing: 48) {
                    Button {
                        // Skip back 15 seconds
                        currentTime = max(0, currentTime - 15)
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.white)
                    }
                    
                    Button {
                        // Skip forward 30 seconds
                        currentTime = min(episode.duration, currentTime + 30)
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
            }
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
}

// Helper extension to convert hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Episode.self, Podcast.self, configurations: config)
    
    let episode = Episode(
        title: "Sample Episode Title",
        podcastTitle: "Sample Podcast",
        podcastAuthor: "Sample Author",
        duration: 2847,
        releaseDate: Date(),
        episodeDescription: "This is a sample description",
        artworkColor: "#FF6B35"
    )
    
    PlayerView(episode: episode)
        .modelContainer(container)
}
