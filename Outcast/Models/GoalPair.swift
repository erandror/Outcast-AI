//
//  GoalPair.swift
//  Outcast
//
//  Represents a pair of goals for the onboarding slider questions
//

import Foundation

/// Represents a pair of values for goal preference questions
struct GoalPair: Identifiable, Sendable {
    let id: String
    let valueA: String
    let valueB: String
    let leftValue: String  // Which value appears on the left (randomized)
    let rightValue: String // Which value appears on the right
    let isSwapped: Bool    // Whether the original pair order was swapped
    
    /// Emoji mappings for each value
    static let valueEmojis: [String: String] = [
        "Truth": "💎",
        "Relationships": "🤝",
        "Certainty": "✅",
        "Complexity": "🧩",
        "Creativity": "🎨",
        "Order": "📐",
        "Curiosity": "🔭",
        "Familiarity": "🏠",
        "Adventure": "🚀",
        "Predictability": "☕️",
        "Learning": "📚",
        "Entertainment": "🎬",
        "Safety": "🛡️",
        "Challenge": "💪",
        "Excitement": "🎉",
        "Calmness": "🧘🏻‍♂️",
        "Energy": "⚡️",
        "Relaxation": "🌴",
        "Freedom": "🦅",
        "Structure": "🍱",
        "Tradition": "🏛️",
        "Invention": "💡",
        "Enjoyment": "😊",
        "Productivity": "📈",
        "Success": "🏆",
        "Community": "👬",
        "Belonging": "🤗",
        "Self-Expression": "🎤",
        "Growth": "🌱",
        "Comfort": "📺"
    ]
    
    /// Emoji for the left value
    var leftEmoji: String {
        Self.valueEmojis[leftValue] ?? ""
    }
    
    /// Emoji for the right value
    var rightEmoji: String {
        Self.valueEmojis[rightValue] ?? ""
    }
    
    /// All 15 goal pairs as defined in the spec
    static let allPairs: [(String, String)] = [
        ("Truth", "Relationships"),
        ("Certainty", "Complexity"),
        ("Creativity", "Order"),
        ("Curiosity", "Familiarity"),
        ("Adventure", "Predictability"),
        ("Learning", "Entertainment"),
        ("Safety", "Challenge"),
        ("Excitement", "Calmness"),
        ("Energy", "Relaxation"),
        ("Freedom", "Structure"),
        ("Tradition", "Invention"),
        ("Enjoyment", "Productivity"),
        ("Success", "Community"),
        ("Belonging", "Self-Expression"),
        ("Growth", "Comfort")
    ]
    
    /// Generate randomized goal pairs (randomizes left/right within each pair)
    static func generateRandomizedPairs() -> [GoalPair] {
        return allPairs.map { pair in
            let shouldSwap = Bool.random()
            return GoalPair(
                id: "\(pair.0)-\(pair.1)",
                valueA: pair.0,
                valueB: pair.1,
                leftValue: shouldSwap ? pair.1 : pair.0,
                rightValue: shouldSwap ? pair.0 : pair.1,
                isSwapped: shouldSwap
            )
        }
    }
    
    /// Convert slider position (0-6) to a normalized score for the original pair
    /// Returns a value where:
    /// - Negative values favor valueA
    /// - Positive values favor valueB
    /// - 0 is neutral
    func normalizedScore(sliderPosition: Int) -> Int {
        // Slider position: 0 (far left) to 6 (far right)
        // Center is 3 (neutral)
        let centeredPosition = sliderPosition - 3  // -3 to +3
        
        if isSwapped {
            // If swapped, invert the score
            return -centeredPosition
        } else {
            return centeredPosition
        }
    }
    
    /// Get a storage key for this goal pair (consistent regardless of randomization)
    var storageKey: String {
        "\(valueA)-\(valueB)"
    }
}

