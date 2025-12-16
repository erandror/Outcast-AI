//
//  ShowHeaderView.swift
//  Outcast
//
//  Collapsible header for podcast detail screen with Liquid Glass effects
//

import SwiftUI

struct ShowHeaderView: View {
    let podcast: PodcastRecord
    @Binding var isExpanded: Bool
    let onToggleUpNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Artwork and title section
            VStack(spacing: 20) {
                // Artwork
                PodcastArtwork(
                    artworkURL: podcast.artworkURL,
                    placeholderColor: podcast.artworkColor,
                    placeholderTitle: podcast.title,
                    size: isExpanded ? .large : .medium
                )
                .frame(width: isExpanded ? 200 : 150, height: isExpanded ? 200 : 150)
                .shadow(color: .white.opacity(0.1), radius: 20)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
                
                // Title with expand/collapse button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(podcast.title)
                            .font(isExpanded ? .title : .title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                
                // Metadata (only when expanded)
                if isExpanded {
                    VStack(spacing: 12) {
                        if let author = podcast.author {
                            Text(author)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        if let description = podcast.podcastDescription {
                            Text(description)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineLimit(4)
                        }
                        
                        if let homePageURL = podcast.homePageURL {
                            Link(destination: URL(string: homePageURL)!) {
                                HStack(spacing: 4) {
                                    Image(systemName: "safari")
                                        .font(.caption)
                                    Text("Visit Website")
                                        .font(.caption)
                                }
                                .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            
            // Action buttons with Liquid Glass
            actionButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .background(Color.black)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        if #available(iOS 26.0, *) {
            // Use Liquid Glass on iOS 26+
            glassActionButtons
        } else {
            // Fallback for older iOS versions
            fallbackActionButtons
        }
    }
    
    @available(iOS 26.0, *)
    private var glassActionButtons: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                Button {
                    // Follow action
                } label: {
                    HStack {
                        Image(systemName: "bell.fill")
                        Text("Follow")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.white.opacity(0.1)), in: .capsule)
                
                Button {
                    onToggleUpNext()
                } label: {
                    HStack {
                        Image(systemName: podcast.isUpNext ? "text.badge.checkmark" : "text.badge.plus")
                        Text("Up Next")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.white.opacity(0.1)), in: .capsule)
                
                Button {
                    // Share action
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.white.opacity(0.1)), in: .capsule)
            }
        }
    }
    
    private var fallbackActionButtons: some View {
        HStack(spacing: 16) {
            Button {
                // Follow action
            } label: {
                HStack {
                    Image(systemName: "bell.fill")
                    Text("Follow")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }
            
            Button {
                onToggleUpNext()
            } label: {
                HStack {
                    Image(systemName: podcast.isUpNext ? "text.badge.checkmark" : "text.badge.plus")
                    Text("Up Next")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }
            
            Button {
                // Share action
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
            }
        }
    }
}

#Preview {
    ShowHeaderView(
        podcast: PodcastRecord(
            feedURL: "https://example.com/feed.xml",
            title: "Sample Podcast",
            author: "Sample Author",
            podcastDescription: "This is a sample podcast description that explains what the show is all about. It can be a few sentences long.",
            homePageURL: "https://example.com",
            artworkColor: "#FF6B35"
        ),
        isExpanded: .constant(true),
        onToggleUpNext: {}
    )
    .background(Color.black)
}
