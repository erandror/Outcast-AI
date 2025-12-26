//
//  WelcomeScreen.swift
//  Outcast
//
//  Welcome screen for onboarding flow
//

import SwiftUI

struct WelcomeScreen: View {
    let onJoinNow: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        ZStack {
            // Full-screen background
            Image("Launch Screens")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo
                Image("Full Logos")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200)
                    .padding(.horizontal, 40)
                
                Spacer()
                    .frame(height: 40)
                
                // Tagline
                Text("Join the world of podcasts.")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 16) {
                    // Join Now - Primary CTA
                    Button {
                        onJoinNow()
                    } label: {
                        Text("Join Now")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    
                    // Sign In - Secondary (disabled)
                    Button {
                        // Non-functional until auth system is built
                    } label: {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .disabled(true)
                    
                    // Skip
                    Button {
                        onSkip()
                    } label: {
                        Text("Skip")
                            .font(.body)
                            .foregroundStyle(.white)
                            .underline()
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    WelcomeScreen(
        onJoinNow: {},
        onSkip: {}
    )
}

