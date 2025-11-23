//
//  WordMemoryState.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 11/11/25.
//

import Foundation

struct WordMemoryState: Codable, Identifiable {
    var id = UUID()
    let word: String
    var lastReviewed: Date
    var confidence: Double // 0.0–1.0
    var correctCount: Int
    var incorrectCount: Int
    
    mutating func updatePerformance(correct: Bool) {
        if correct {
            correctCount += 1
            confidence = min(1.0, confidence + 0.15)
        } else {
            incorrectCount += 1
            confidence = max(0.0, confidence - 0.25)
        }
        lastReviewed = Date()
    }
    
    mutating func applyDecay() {
        let hoursSince = Date().timeIntervalSince(lastReviewed) / 3600.0
        confidence *= exp(-hoursSince / 48.0) // 2-day half-life
        confidence = max(0.0, confidence)
    }
}
