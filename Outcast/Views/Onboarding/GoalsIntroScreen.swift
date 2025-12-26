//
//  GoalsIntroScreen.swift
//  Outcast
//
//  Introduction screen before goal slider questions
//

import SwiftUI

struct GoalsIntroScreen: View {
    let onContinue: () -> Void
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Icon
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 32)
                
                // Title
                Text("Let's personalize your experience")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                
                // Explanation
                Text("In order to suggest the best shows for you, we need to learn a little bit about your preferences.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Continue Button
                Button {
                    onContinue()
                } label: {
                    HStack {
                        Text("I'm Ready")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    GoalsIntroScreen(onContinue: {})
}

