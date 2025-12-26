//
//  ParentCategoriesScreen.swift
//  Outcast
//
//  Parent categories selection screen for onboarding
//

import SwiftUI

struct ParentCategoriesScreen: View {
    @Binding var selectedParentCategoryIds: Set<Int64>
    let onContinue: () -> Void
    
    @State private var parentCategories: [ParentCategoryRecord] = []
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title
                Text("What interests you?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                
                // Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(parentCategories, id: \.id) { category in
                            if let categoryId = category.id {
                                ParentCategoryCard(
                                    emoji: category.emoji,
                                    label: category.label,
                                    isSelected: selectedParentCategoryIds.contains(categoryId)
                                ) {
                                    toggleSelection(categoryId)
                                }
                            }
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
                        .background(selectedParentCategoryIds.isEmpty ? Color.white.opacity(0.3) : Color.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedParentCategoryIds.isEmpty)
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
            await loadParentCategories()
        }
    }
    
    private func toggleSelection(_ id: Int64) {
        if selectedParentCategoryIds.contains(id) {
            selectedParentCategoryIds.remove(id)
        } else {
            selectedParentCategoryIds.insert(id)
        }
    }
    
    private func loadParentCategories() async {
        do {
            let loaded = try await AppDatabase.shared.readAsync { db in
                try ParentCategoryRecord.fetchAll(db: db)
            }
            await MainActor.run {
                parentCategories = loaded
            }
        } catch {
            print("Failed to load parent categories: \(error)")
        }
    }
}

private struct ParentCategoryCard: View {
    let emoji: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 40))
                
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ParentCategoriesScreen(
        selectedParentCategoryIds: .constant([1, 2]),
        onContinue: {}
    )
}

