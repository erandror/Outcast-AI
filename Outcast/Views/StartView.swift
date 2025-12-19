//
//  StartView.swift
//  Outcast
//
//  Start tab with grid of playable filter cards
//

import SwiftUI

struct StartView: View {
    let topicFilters: [SystemTagRecord]
    let onSelectFilter: (ListenFilter) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                // Mood Filters Section
                ForEach(ForYouFilter.allCases, id: \.self) { moodFilter in
                    FilterCard(
                        emoji: moodFilter.emoji,
                        label: moodFilter.label
                    ) {
                        onSelectFilter(.standard(moodFilter))
                    }
                }
                
                // Topic Filters Section
                ForEach(topicFilters, id: \.uuid) { topic in
                    FilterCard(
                        emoji: topic.emoji ?? "🏷️",
                        label: topic.name
                    ) {
                        onSelectFilter(.topic(topic))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100) // Extra padding for mini player
        }
    }
}

private struct FilterCard: View {
    let emoji: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                // Card background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                // Content
                VStack(spacing: 8) {
                    // Emoji
                    Text(emoji)
                        .font(.system(size: 40))
                    
                    // Label
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                
                // Play button in bottom right corner
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .padding(12)
            }
            .frame(height: 140)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StartView(
        topicFilters: [
            SystemTagRecord(
                type: .topic,
                name: "Technology",
                emoji: "💻",
                displayOrder: 0
            ),
            SystemTagRecord(
                type: .topic,
                name: "Science",
                emoji: "🔬",
                displayOrder: 1
            )
        ],
        onSelectFilter: { _ in }
    )
    .background(Color.black)
}

