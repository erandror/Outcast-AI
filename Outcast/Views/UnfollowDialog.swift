//
//  UnfollowDialog.swift
//  Outcast
//
//  Dialog for prompting to unfollow a podcast after multiple downvotes
//

import SwiftUI

struct UnfollowDialog: View {
    let podcast: PodcastRecord
    let downvoteCount: Int
    let onRemoveFromUpNext: () -> Void
    let onUnfollow: () -> Void
    let onKeep: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {  // Use VStack spacing for reliable gaps between elements
            // Podcast title as header
            Text(podcast.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Podcast artwork
            PodcastArtwork(
                podcast: podcast,
                size: .episodeRow  // 110pt
            )
            
            // Body text with downvote count
            Text("This is the \(ordinal(downvoteCount)) episode you've downvoted from this podcast. Would you like to:")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Action buttons
            VStack(spacing: 12) {
                // Conditional "Remove from Up Next" button
                if podcast.isUpNext {
                    Button {
                        dismiss()
                        onRemoveFromUpNext()
                    } label: {
                        Text("Remove from Up Next")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }
                
                // Unfollow button
                Button {
                    dismiss()
                    onUnfollow()
                } label: {
                    Text("Unfollow")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(12)
                }
                
                // Keep button
                Button {
                    dismiss()
                    onKeep()
                } label: {
                    Text("Keep")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: 400)
    }
    
    /// Convert number to ordinal (e.g., 2 -> "2nd", 3 -> "3rd")
    private func ordinal(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)th"
    }
}

#Preview {
    let podcast = PodcastRecord(
        feedURL: "https://example.com/feed.xml",
        title: "The Lex Fridman Podcast",
        author: "Lex Fridman",
        artworkColor: "#FF6B35",
        isUpNext: true
    )
    
    return UnfollowDialog(
        podcast: podcast,
        downvoteCount: 2,
        onRemoveFromUpNext: { print("Remove from Up Next") },
        onUnfollow: { print("Unfollow") },
        onKeep: { print("Keep") }
    )
}
