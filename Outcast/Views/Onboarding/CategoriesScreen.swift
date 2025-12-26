//
//  CategoriesScreen.swift
//  Outcast
//
//  Categories selection screen grouped by parent categories
//

import SwiftUI

struct CategoriesScreen: View {
    let selectedParentCategoryIds: Set<Int64>
    @Binding var selectedCategoryIds: Set<Int64>
    let onContinue: () -> Void
    
    @State private var categoriesByParent: [(parent: ParentCategoryRecord, categories: [CategoryRecord])] = []
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title
                Text("Narrow it down")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                
                // Scrollable Content
                ScrollView {
                    VStack(spacing: 32) {
                        ForEach(categoriesByParent, id: \.parent.id) { group in
                            CategoryGroup(
                                parent: group.parent,
                                categories: group.categories,
                                selectedCategoryIds: $selectedCategoryIds
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 120) // Space for button
                }
                
                // Fixed Continue Button
                VStack {
                    Button {
                        onContinue()
                    } label: {
                        HStack {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedCategoryIds.isEmpty ? Color.white.opacity(0.3) : Color.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedCategoryIds.isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .offset(y: -80)
                )
            }
        }
        .task {
            await loadCategories()
        }
    }
    
    private func loadCategories() async {
        do {
            let grouped = try await AppDatabase.shared.readAsync { db in
                var result: [(parent: ParentCategoryRecord, categories: [CategoryRecord])] = []
                
                for parentId in selectedParentCategoryIds {
                    if let parent = try ParentCategoryRecord.fetchById(parentId, db: db) {
                        let categories = try CategoryRecord.fetchByParent(parentId, db: db)
                        if !categories.isEmpty {
                            result.append((parent: parent, categories: categories))
                        }
                    }
                }
                
                // Sort by parent label
                return result.sorted { $0.parent.label < $1.parent.label }
            }
            
            await MainActor.run {
                categoriesByParent = grouped
            }
        } catch {
            print("Failed to load categories: \(error)")
        }
    }
}

private struct CategoryGroup: View {
    let parent: ParentCategoryRecord
    let categories: [CategoryRecord]
    @Binding var selectedCategoryIds: Set<Int64>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Parent Header
            HStack(spacing: 8) {
                Text(parent.emoji)
                    .font(.title2)
                Text(parent.label.capitalized)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            // Category Badges
            FlowLayout(spacing: 10) {
                ForEach(categories, id: \.id) { category in
                    if let categoryId = category.id {
                        CategoryBadge(
                            emoji: category.emoji,
                            label: category.label,
                            isSelected: selectedCategoryIds.contains(categoryId)
                        ) {
                            toggleSelection(categoryId)
                        }
                    }
                }
            }
        }
    }
    
    private func toggleSelection(_ id: Int64) {
        if selectedCategoryIds.contains(id) {
            selectedCategoryIds.remove(id)
        } else {
            selectedCategoryIds.insert(id)
        }
    }
}

private struct CategoryBadge: View {
    let emoji: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.body)
                Text(label.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// Simple flow layout for wrapping badges
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    // Move to next line
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    CategoriesScreen(
        selectedParentCategoryIds: [1, 2],
        selectedCategoryIds: .constant([10, 15]),
        onContinue: {}
    )
}

