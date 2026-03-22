//
//  ExerciseEngine.swift
//  Patente-Learning
//
//  Central engine for the Duolingo-style exercise system.
//
//  Responsibilities
//  ────────────────
//  • Define the ExerciseCard enum (one case per exercise type)
//  • Route each word to the right exercise type based on correctCount
//  • Build the ordered queue for a lesson session
//  • Track session-level state (hearts, score, re-queue logic)
//

import Foundation

// MARK: - Exercise Types

/// One discrete exercise card shown to the user.
enum ExerciseCard: Identifiable {
    /// 4–6 word pairs to match (shown once, at the start of a session)
    case tapThePairs(pairs: [WordPair])

    /// "What does [italian] mean?" — 4 English answer choices
    case whatDoesItMean(word: Words, choices: [String])

    /// "How do you say [english] in Italian?" — 4 Italian answer choices
    case howDoYouSay(word: Words, choices: [String])

    /// "[italian] = [english] — True or False?"
    case trueFalse(word: Words, displayedTranslation: String, isCorrect: Bool)

    /// Show an Italian word, pick the correct English tile from a bank
    case wordBank(word: Words, bank: [String])

    /// Fill in the blank using an example sentence  (correctCount ≥ 3)
    case fillInTheBlank(word: Words, maskedSentence: String, choices: [String])

    var id: String {
        switch self {
        case .tapThePairs:                    return "pairs-\(UUID())"
        case .whatDoesItMean(let w, _):       return "wdim-\(w.italian)"
        case .howDoYouSay(let w, _):          return "hdys-\(w.italian)"
        case .trueFalse(let w, _, _):         return "tf-\(w.italian)-\(UUID())"
        case .wordBank(let w, _):             return "wb-\(w.italian)"
        case .fillInTheBlank(let w, _, _):    return "fitb-\(w.italian)"
        }
    }
}

// MARK: - Supporting Types

struct WordPair: Identifiable {
    let id = UUID()
    let italian: String
    let english: String
}

// MARK: - Exercise Router

/// Decides which exercise type a word should receive based on its review history.
enum ExerciseRouter {
    static func exerciseType(for memoryState: WordMemoryState?) -> ExerciseType {
        let count = memoryState?.correctCount ?? 0
        switch count {
        case 0:        return .whatDoesItMean
        case 1:        return .howDoYouSay
        case 2:        return Bool.random() ? .trueFalse : .wordBank
        default:       return Bool.random() ? .fillInTheBlank : .wordBank
        }
    }
}

enum ExerciseType {
    case whatDoesItMean
    case howDoYouSay
    case trueFalse
    case wordBank
    case fillInTheBlank
}

// MARK: - Session Builder

/// Assembles the full ordered card queue for a lesson session.
struct SessionBuilder {

    /// All words in the chapter/lesson — used as the distractor pool.
    let allWords: [Words]

    /// The words this specific session will cover.
    let sessionWords: [Words]

    /// Memory states keyed by Italian word string.
    let memoryStates: [String: WordMemoryState]

    // MARK: Build

    func buildQueue() -> [ExerciseCard] {
        var queue: [ExerciseCard] = []

        // ── 1. Tap the Pairs (intro batch) ────────────────────────────────
        //    Show up to 6 new/weak words as a matching game first.
        let pairCandidates = sessionWords
            .filter { (memoryStates[$0.italian]?.correctCount ?? 0) == 0 }
            .shuffled()
            .prefix(6)

        if pairCandidates.count >= 2 {
            let pairs = pairCandidates.map { WordPair(italian: $0.italian, english: $0.english) }
            queue.append(.tapThePairs(pairs: pairs))
        }

        // ── 2. Individual cards per word ──────────────────────────────────
        for word in sessionWords.shuffled() {
            let state = memoryStates[word.italian]
            let type  = ExerciseRouter.exerciseType(for: state)
            if let card = makeCard(for: word, type: type) {
                queue.append(card)
            }
        }

        return queue
    }

    // MARK: Card Factory

    private func makeCard(for word: Words, type: ExerciseType) -> ExerciseCard? {
        switch type {

        case .whatDoesItMean:
            let choices = buildEnglishChoices(correct: word.english)
            return .whatDoesItMean(word: word, choices: choices)

        case .howDoYouSay:
            let choices = buildItalianChoices(correct: word.italian)
            return .howDoYouSay(word: word, choices: choices)

        case .trueFalse:
            // 50 % chance of showing the WRONG translation to keep it interesting
            let showWrong = Bool.random()
            if showWrong, let impostor = allWords.filter({ $0.english != word.english }).randomElement() {
                return .trueFalse(word: word, displayedTranslation: impostor.english, isCorrect: false)
            } else {
                return .trueFalse(word: word, displayedTranslation: word.english, isCorrect: true)
            }

        case .wordBank:
            let bank = buildWordBank(correct: word.english)
            return .wordBank(word: word, bank: bank)

        case .fillInTheBlank:
            guard let example = word.examples?.first else {
                // Graceful fallback: use word bank if no example sentence
                let bank = buildWordBank(correct: word.english)
                return .wordBank(word: word, bank: bank)
            }
            let masked = example.sentence.replacingOccurrences(
                of: word.italian,
                with: "______",
                options: .caseInsensitive
            )
            let choices = buildItalianChoices(correct: word.italian)
            return .fillInTheBlank(word: word, maskedSentence: masked, choices: choices)
        }
    }

    // MARK: Distractor Helpers

    private func buildEnglishChoices(correct: String) -> [String] {
        let distractors = allWords
            .filter { $0.english != correct }
            .shuffled()
            .prefix(3)
            .map { $0.english }
        return (distractors + [correct]).shuffled()
    }

    private func buildItalianChoices(correct: String) -> [String] {
        let distractors = allWords
            .filter { $0.italian != correct }
            .shuffled()
            .prefix(3)
            .map { $0.italian }
        return (distractors + [correct]).shuffled()
    }

    private func buildWordBank(correct: String) -> [String] {
        let distractors = allWords
            .filter { $0.english != correct }
            .shuffled()
            .prefix(4)
            .map { $0.english }
        return (distractors + [correct]).shuffled()
    }
}
