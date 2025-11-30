//
//  ForYouFilterBar.swift
//  Outcast
//
//  Horizontal scrolling tab bar for For You page filters
//

import SwiftUI

struct ForYouFilterBar: View {
    @Binding var selectedFilter: ForYouFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ForYouFilter.allCases, id: \.self) { filter in
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
        }
        .background(Color.black)
    }
}

private struct FilterTab: View {
    let filter: ForYouFilter
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
        ForYouFilterBar(selectedFilter: .constant(.latest))
        Spacer()
    }
    .background(Color.black)
}
