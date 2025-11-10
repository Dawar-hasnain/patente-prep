//
//  LearningViewModel.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//

import Foundation
import Combine

class LearningViewModel: ObservableObject {
    @Published var words: [Words]
    @Published var currentIndex: Int = 0
    @Published var learnedWords: Set<String> = []
    
    init(words: [Words]) {
        self.words = words
        loadProgress()
        setStartingIndex()
    }
    
    var currentWord: Words {
        words[currentIndex]
    }
    
    func nextWord() {
        if currentIndex < words.count - 1 {
            currentIndex += 1
        }
    }
    
    func previousWord() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
    
    func markAsLearned() {
        learnedWords.insert(currentWord.italian)
        saveProgress()
        nextWord()
    }
    
    private func saveProgress() {
        UserDefaults.standard.set(Array(learnedWords), forKey: "learnedWords")
    }
    
    private func loadProgress() {
        if let saved = UserDefaults.standard.array(forKey: "learnedWords") as? [String] {
            learnedWords = Set(saved)
        }
    }
    
    /// Sets the starting index to the first unlearned word,
    /// or the last word if all are learned.
    private func setStartingIndex() {
        // Find the first unlearned word
        if let nextUnlearnedIndex = words.firstIndex(where: { !learnedWords.contains($0.italian) }) {
            currentIndex = nextUnlearnedIndex
        } else {
            // All learned → show the last word
            currentIndex = max(0, words.count - 1)
        }
    }
    
    func generateRecallQuestions(from words: [Words]) -> [RecallQuestion] {
        var questions: [RecallQuestion] = []

        for word in words {
            if let example = word.examples?.randomElement() {
                let maskedSentence = example.sentence.replacingOccurrences(of: word.italian, with: "_____")
                let question = RecallQuestion(sentence: maskedSentence, answer: word.italian)
                questions.append(question)
            }
        }

        return questions.shuffled()
    }


}
