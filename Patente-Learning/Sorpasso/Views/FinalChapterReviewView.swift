//
//  FinalChapterReviewView.swift
//  Patente-Learning
//
//  Final chapter gate shown after all words have been seen at least once.
//  Presents a full LessonSessionView over every chapter word, then hands
//  off to ChapterMasteryView when the session is complete.
//
//  Removed dependency on the deleted ReviewQuestion / ReviewQuestionView
//  types — the Duolingo exercise engine (ExerciseEngine + LessonSessionView)
//  now owns all question generation and scoring.
//

import SwiftUI

struct FinalChapterReviewView: View {
    let chapter: ChapterList
    @Environment(\.dismiss) private var dismiss

    @State private var sessionCompleted = false
    @State private var retakeID = UUID()   // bumping this resets LessonSessionView

    // Lazy: computed once and cached so retakes get the same word list
    private var chapterWords: [Words] { loadChapter(chapter.filename).words }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if sessionCompleted {
                // ── Chapter Mastery screen ──────────────────────────────────
                ChapterMasteryView(
                    chapter: chapter,
                    score: masteryScore(),
                    onRetake: {
                        // Reset the session view completely
                        sessionCompleted = false
                        retakeID = UUID()
                    }
                )
                .transition(.opacity)

            } else {
                // ── Duolingo-style review session over all chapter words ────
                LessonSessionView(
                    sessionWords: chapterWords,
                    allWords: chapterWords,
                    onFinish: handleSessionFinished
                )
                .id(retakeID)   // replacing the id tears down and rebuilds the view
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessionCompleted)
        .animation(.easeInOut(duration: 0.3), value: retakeID)
    }

    // MARK: - Session Completion

    private func handleSessionFinished() {
        let score = masteryScore()
        ProgressManager.shared.markChapterAsMastered(chapter, score: score)
        XPManager.shared.award(.chapterMastered)
        withAnimation { sessionCompleted = true }
    }

    // MARK: - Score

    /// Fraction of chapter words with ≥ 2 correct memory-state answers.
    private func masteryScore() -> Double {
        let words = chapterWords
        guard !words.isEmpty else { return 1.0 }
        let stateMap: [String: WordMemoryState] = Dictionary(
            uniqueKeysWithValues: ProgressManager.shared.allMemoryStates().map { ($0.word, $0) }
        )
        let masteredCount = words.filter { (stateMap[$0.italian]?.correctCount ?? 0) >= 2 }.count
        return Double(masteredCount) / Double(words.count)
    }
}

// MARK: - Preview

#Preview {
    FinalChapterReviewView(chapter: .la_strada)
}
