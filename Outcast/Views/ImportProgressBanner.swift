//
//  ImportProgressBanner.swift
//  Outcast
//
//  Banner showing import progress while syncing podcasts
//

import SwiftUI

struct ImportProgressBanner: View {
    let progress: ImportCoordinator.ImportProgress
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated progress indicator
            ProgressView()
                .tint(.white)
                .scaleEffect(0.8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Syncing Podcasts")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("\(progress.completed) of \(progress.total) completed")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Progress percentage
            Text("\(Int(progress.successRate * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            ImportProgressBanner(
                progress: ImportCoordinator.ImportProgress(
                    total: 50,
                    completed: 25,
                    failed: 2,
                    currentPodcast: "Example Podcast"
                )
            )
            Spacer()
        }
    }
}
