//
//  ForYouFilterBar.swift
//  Outcast
//
//  Horizontal scrolling tab bar for For You page filters
//

import SwiftUI

struct ForYouFilterBar: View {
    @Binding var selectedFilter: ListenFilter
    let topicFilters: [SystemTagRecord]
    
    /// Build the complete filter array: topics (sorted by popularity) + Up Next + mood filters
    private var allFilters: [ListenFilter] {
        var filters: [ListenFilter] = []
        
        // Add topic filters (reversed so most popular is closest to center)
        let sortedTopics = topicFilters.reversed()
        filters.append(contentsOf: sortedTopics.map { .topic($0) })
        
        // Add Up Next in the center
        filters.append(.standard(.upNext))
        
        // Add remaining mood/time filters (excluding upNext which is already added)
        let standardFilters = ForYouFilter.allCases.filter { $0 != .upNext }
        filters.append(contentsOf: standardFilters.map { .standard($0) })
        
        return filters
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(allFilters, id: \.id) { filter in
                        FilterTab(
                            filter: filter,
                            isSelected: selectedFilter.id == filter.id
                        ) {
                            selectedFilter = filter
                        }
                        .id(filter.id)
                    }
                }
                .padding(.horizontal, UIScreen.main.bounds.width / 2 - 60)
                .padding(.vertical, 12)
            }
            .onChange(of: selectedFilter) { _, newFilter in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newFilter.id, anchor: .center)
                }
            }
            .onChange(of: topicFilters) {
                // Re-center when topic filters load
                proxy.scrollTo(selectedFilter.id, anchor: .center)
            }
            .onAppear {
                // Scroll to initial selection without animation
                proxy.scrollTo(selectedFilter.id, anchor: .center)
            }
        }
        .background(Color.black)
    }
}

private struct FilterTab: View {
    let filter: ListenFilter
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

#Preview {
    VStack {
        ForYouFilterBar(
            selectedFilter: .constant(.standard(.upNext)),
            topicFilters: []
        )
        Spacer()
    }
    .background(Color.black)
}
