//
//  GoalSliderScreen.swift
//  Outcast
//
//  Goal preference slider screen with 7 positions
//

import SwiftUI

struct GoalSliderScreen: View {
    let goalPair: GoalPair
    let currentIndex: Int
    let totalCount: Int
    @Binding var sliderValue: Double
    let onContinue: () -> Void
    
    var isLastQuestion: Bool {
        currentIndex == totalCount - 1
    }
    
    var discreteValue: Int {
        Int(sliderValue.rounded())
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Step counter
                Text("\(currentIndex + 1) of \(totalCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 60)
                
                Spacer()
                    .frame(height: 60)
                
                // Title
                VStack(spacing: 8) {
                    Text("Which is more important to you")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text("\(goalPair.leftValue) or \(goalPair.rightValue)?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 80)
                
                // Value Labels
                HStack {
                    HStack(spacing: 6) {
                        Text(goalPair.leftEmoji)
                            .font(.title3)
                        Text(goalPair.leftValue)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(discreteValue < 3 ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text(goalPair.rightValue)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(goalPair.rightEmoji)
                            .font(.title3)
                    }
                    .foregroundStyle(discreteValue > 3 ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Slider with 7 positions
                VStack(spacing: 12) {
                    // Position dots
                    HStack(spacing: 0) {
                        ForEach(0..<7) { position in
                            Circle()
                                .fill(discreteValue == position ? Color.white : Color.white.opacity(0.3))
                                .frame(width: discreteValue == position ? 12 : 8, height: discreteValue == position ? 12 : 8)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Slider
                    Slider(value: $sliderValue, in: 0...6, step: 1)
                        .tint(.white)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
                
                // Position label
                Text(positionLabel)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 20)
                
                Spacer()
                
                // Continue Button
                Button {
                    onContinue()
                } label: {
                    HStack {
                        Text(isLastQuestion ? "Save and Continue" : "Continue")
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
    
    private var positionLabel: String {
        switch discreteValue {
        case 0: return "Strongly prefer \(goalPair.leftValue)"
        case 1: return "Prefer \(goalPair.leftValue)"
        case 2: return "Slightly prefer \(goalPair.leftValue)"
        case 3: return "Neutral"
        case 4: return "Slightly prefer \(goalPair.rightValue)"
        case 5: return "Prefer \(goalPair.rightValue)"
        case 6: return "Strongly prefer \(goalPair.rightValue)"
        default: return "Neutral"
        }
    }
}

#Preview {
    GoalSliderScreen(
        goalPair: GoalPair(
            id: "Truth-Relationships",
            valueA: "Truth",
            valueB: "Relationships",
            leftValue: "Truth",
            rightValue: "Relationships",
            isSwapped: false
        ),
        currentIndex: 0,
        totalCount: 15,
        sliderValue: .constant(3),
        onContinue: {}
    )
}

