//
//  OnboardingCoordinator.swift
//  Outcast
//
//  Coordinates the onboarding flow and manages state
//

import SwiftUI

struct OnboardingCoordinator: View {
    let onComplete: () -> Void
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var fullName: String = ""
    @State private var phoneNumber: String = ""
    @State private var countryCode: String = "+1"
    @State private var selectedParentCategoryIds: Set<Int64> = []
    @State private var selectedCategoryIds: Set<Int64> = []
    @State private var goalPairs: [GoalPair] = []
    @State private var goalAnswers: [String: Double] = [:]
    @State private var currentGoalIndex: Int = 0
    
    enum OnboardingStep: Equatable {
        case welcome
        case fullName
        case phone
        case parentCategories
        case categories
        case goalsIntro
        case goalSlider(index: Int)
        case complete
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeScreen(
                        onJoinNow: { currentStep = .fullName },
                        onSkip: { onComplete() }
                    )
                    
                case .fullName:
                    FullNameScreen(
                        fullName: $fullName,
                        onContinue: { currentStep = .phone }
                    )
                    
                case .phone:
                    PhoneNumberScreen(
                        phoneNumber: $phoneNumber,
                        countryCode: $countryCode,
                        onContinue: { currentStep = .parentCategories }
                    )
                    
                case .parentCategories:
                    ParentCategoriesScreen(
                        selectedParentCategoryIds: $selectedParentCategoryIds,
                        onContinue: { currentStep = .categories }
                    )
                    
                case .categories:
                    CategoriesScreen(
                        selectedParentCategoryIds: selectedParentCategoryIds,
                        selectedCategoryIds: $selectedCategoryIds,
                        onContinue: {
                            // Initialize goal pairs before showing intro
                            goalPairs = GoalPair.generateRandomizedPairs()
                            // Initialize all answers to neutral (3)
                            for pair in goalPairs {
                                goalAnswers[pair.storageKey] = 3.0
                            }
                            currentStep = .goalsIntro
                        }
                    )
                    
                case .goalsIntro:
                    GoalsIntroScreen(
                        onContinue: {
                            currentGoalIndex = 0
                            currentStep = .goalSlider(index: 0)
                        }
                    )
                    
                case .goalSlider(let index):
                    if index < goalPairs.count {
                        let pair = goalPairs[index]
                        GoalSliderScreen(
                            goalPair: pair,
                            currentIndex: index,
                            totalCount: goalPairs.count,
                            sliderValue: Binding(
                                get: { goalAnswers[pair.storageKey] ?? 3.0 },
                                set: { goalAnswers[pair.storageKey] = $0 }
                            ),
                            onContinue: {
                                if index < goalPairs.count - 1 {
                                    // Move to next question
                                    currentGoalIndex = index + 1
                                    currentStep = .goalSlider(index: index + 1)
                                } else {
                                    // All questions answered, save profile
                                    Task {
                                        await saveProfile()
                                    }
                                }
                            }
                        )
                    }
                    
                case .complete:
                    // This state should immediately trigger onComplete
                    Color.clear
                        .onAppear {
                            onComplete()
                        }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                // Show back button for all steps except welcome
                if currentStep != .welcome {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            navigateBack()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.body.weight(.semibold))
                                Text("Back")
                            }
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func navigateBack() {
        switch currentStep {
        case .welcome:
            break
        case .fullName:
            currentStep = .welcome
        case .phone:
            currentStep = .fullName
        case .parentCategories:
            currentStep = .phone
        case .categories:
            currentStep = .parentCategories
        case .goalsIntro:
            currentStep = .categories
        case .goalSlider(let index):
            if index > 0 {
                currentStep = .goalSlider(index: index - 1)
            } else {
                currentStep = .goalsIntro
            }
        case .complete:
            break
        }
    }
    
    private func saveProfile() async {
        do {
            // Convert goal answers from Double to Int
            let intGoalAnswers = goalAnswers.mapValues { Int($0.rounded()) }
            
            try await AppDatabase.shared.writeAsync { db in
                try ProfileRecord.saveProfile(
                    fullName: fullName.trimmingCharacters(in: .whitespaces),
                    phoneNumber: phoneNumber.trimmingCharacters(in: .whitespaces),
                    countryCode: countryCode,
                    selectedParentCategoryIds: Array(selectedParentCategoryIds),
                    selectedCategoryIds: Array(selectedCategoryIds),
                    goalAnswers: intGoalAnswers,
                    onboardingCompleted: true,
                    db: db
                )
            }
            
            await MainActor.run {
                currentStep = .complete
            }
        } catch {
            print("Failed to save profile: \(error)")
            // Still complete the onboarding even if save fails
            await MainActor.run {
                currentStep = .complete
            }
        }
    }
}

#Preview {
    OnboardingCoordinator(onComplete: {})
}

