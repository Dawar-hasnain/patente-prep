//
//  FinalChapterReviewView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//

import SwiftUI

struct FinalChapterReviewView: View {
    let chapter: ChapterList

    @State private var questions: [ReviewQuestion] = []
    @State private var currentIndex = 0
    @State private var correctCount = 0
    @State private var answered = false
    @State private var selectedOption: String? = nil
    @State private var finished = false
    @State private var score: Double = 0.0

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if finished {
                ChapterMasteryView(chapter: chapter, score: score)
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

    // MARK: - Logic

    private func generateQuestions() {
        let words = loadChapter(chapter.filename).words
        guard !words.isEmpty else { return }

        var generated: [ReviewQuestion] = []

        // Multiple choice (10)
        for word in words.shuffled().prefix(10) {
            let options = (words.shuffled().prefix(3).map { $0.english } + [word.english]).shuffled()
            generated.append(
                ReviewQuestion(
                    type: .multipleChoice,
                    italian: word.italian,
                    correctAnswer: word.english,
                    options: Array(Set(options)),
                    sentence: nil
                )
            )
        }

        // Fill-the-gap (5)
        for word in words.shuffled().prefix(5) {
            if let example = word.examples?.first {
                let sentence = example.sentence.replacingOccurrences(of: word.italian, with: "____")
                generated.append(
                    ReviewQuestion(
                        type: .fillGap,
                        italian: word.italian,
                        correctAnswer: word.italian,
                        options: Array(Set([word.italian] + words.shuffled().prefix(3).map { $0.italian })).shuffled(),
                        sentence: sentence
                    )
                )
            }
        }

        questions = generated.shuffled()
    }

    private func nextQuestion() {
        guard let selected = selectedOption else { return }
        let correct = questions[currentIndex].correctAnswer
        if selected == correct { correctCount += 1 }

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
    }
}
