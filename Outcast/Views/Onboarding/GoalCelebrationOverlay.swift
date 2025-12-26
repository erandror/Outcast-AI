//
//  GoalCelebrationOverlay.swift
//  Outcast
//
//  Full-screen celebration overlay with emoji animation
//

import SwiftUI

struct GoalCelebrationOverlay: View {
    let emoji: String
    let isPresented: Bool
    
    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                Text(emoji)
                    .font(.system(size: 120))
                    .scaleEffect(isPresented ? 1.0 : 0.3)
                    .opacity(isPresented ? 1.0 : 0)
                    .shadow(color: .white.opacity(0.5), radius: 30)
            }
            .transition(.opacity)
        }
    }
}

#Preview {
    GoalCelebrationOverlay(emoji: "🎉", isPresented: true)
}

