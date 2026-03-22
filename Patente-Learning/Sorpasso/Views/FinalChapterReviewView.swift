//
//  FinalChapterReviewView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//

import SwiftUI

struct FinalChapterReviewView: View {
    let chapter: ChapterList
    @Environment(\.dismiss) private var dismiss

    @State private var questions: [ReviewQuestion] = []
    @State private var currentIndex = 0
    @State private var correctCount = 0
    @State private var answered = false
    @State private var selectedOption: String? = nil
    @State private var finished = false
    @State private var score: Double = 0.0
    @State private var showRetake = false   // drives retake via state, not window swap

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if showRetake {
                // Inline retake — reset state and replay
                Color.clear.onAppear { resetForRetake() }
            } else if finished {
                ChapterMasteryView(
                    chapter: chapter,
                    score: score,
                    onRetake: { showRetake = true }
                )
            } else if !questions.isEmpty {
                let q = questions[currentIndex]

                VStack(spacing: 30) {
                    Text("Final Review \(currentIndex + 1) of \(questions.count)")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ReviewQuestionView(
                        question: q,
                        selectedOption: $selectedOption,
                        answered: $answered
                    )
                    .padding(.horizontal)

                    if answered {
                        Button(action: nextQuestion) {
                            Text(currentIndex == questions.count - 1 ? "Finish Chapter" : "Next Question")
                                .font(.headline)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .transition(.opacity)
                    }

                    Spacer()
                }
                .padding()
                .animation(.easeInOut, value: answered)
            } else {
                ProgressView("Preparing final review…")
                    .onAppear(perform: generateQuestions)
            }
        }
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Question Generation

    private func generateQuestions() {
        let words = loadChapter(chapter.filename).words
        guard !words.isEmpty else { return }

        var generated: [ReviewQuestion] = []

        // Multiple choice (10)
        for word in words.shuffled().prefix(10) {
            let distractors = words.filter { $0.english != word.english }.shuffled().prefix(3).map { $0.english }
            let options = Array(Set(distractors + [word.english])).shuffled()
            generated.append(ReviewQuestion(
                type: .multipleChoice,
                italian: word.italian,
                correctAnswer: word.english,
                options: options,
                sentence: nil
            ))
        }

        // Fill-the-gap (5)
        for word in words.shuffled().prefix(5) {
            if let example = word.examples?.first {
                let masked = example.sentence.replacingOccurrences(of: word.italian, with: "____")
                let distractors = words.filter { $0.italian != word.italian }.shuffled().prefix(3).map { $0.italian }
                let options = Array(Set(distractors + [word.italian])).shuffled()
                generated.append(ReviewQuestion(
                    type: .fillGap,
                    italian: word.italian,
                    correctAnswer: word.italian,
                    options: options,
                    sentence: masked
                ))
            }
        }

        // True / False (5) — uses existing vero/falso example data
        let tfCandidates = words.filter { $0.examples?.isEmpty == false }
        for word in tfCandidates.shuffled().prefix(5) {
            if let example = word.examples?.randomElement() {
                generated.append(ReviewQuestion(
                    type: .trueFalso,
                    italian: word.italian,
                    correctAnswer: example.label,
                    options: [],
                    sentence: example.sentence
                ))
            }
        }

        questions = generated.shuffled()
    }

    // MARK: - Navigation

    private func nextQuestion() {
        guard let selected = selectedOption else { return }
        if selected == questions[currentIndex].correctAnswer { correctCount += 1 }

        if currentIndex < questions.count - 1 {
            currentIndex += 1
            answered = false
            selectedOption = nil
        } else {
            finishReview()
        }
    }

    private func finishReview() {
        score = Double(correctCount) / Double(questions.count)
        finished = true
        ProgressManager.shared.markChapterAsMastered(chapter, score: score)
        XPManager.shared.award(.chapterMastered)
    }

    private func resetForRetake() {
        questions = []
        currentIndex = 0
        correctCount = 0
        answered = false
        selectedOption = nil
        finished = false
        score = 0.0
        showRetake = false
        generateQuestions()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FinalChapterReviewView(chapter: .la_strada)
    }
}
