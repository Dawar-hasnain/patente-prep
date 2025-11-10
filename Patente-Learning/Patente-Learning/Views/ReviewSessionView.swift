//
//  ReviewSessionView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//

import SwiftUI

struct ReviewSessionView: View {
    let chapter: ChapterList
    let currentProgress: Double
    let onCompletion: (_ passed: Bool, _ score: Double) -> Void

    @State private var questions: [ReviewQuestion] = []
    @State private var currentIndex = 0
    @State private var correctCount = 0
    @State private var answered = false
    @State private var selectedOption: String? = nil
    @State private var showResults = false

    private let progressManager = ProgressManager.shared

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if showResults {
                ReviewResultView(
                    correctCount: correctCount,
                    total: questions.count,
                    progress: currentProgress,
                    onContinue: handleCompletion
                )
            } else if !questions.isEmpty {
                let q = questions[currentIndex]

                VStack(spacing: 30) {
                    Text("Review \(currentIndex + 1) of \(questions.count)")
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
                            Text(currentIndex == questions.count - 1 ? "Finish Review" : "Next Question")
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
                ProgressView("Preparing questions…")
                    .onAppear(perform: generateQuestions)
            }
        }
        .animation(.easeInOut, value: showResults)
    }

    // MARK: - Question logic
    private func generateQuestions() {
        // Load all words from current chapter
        let words = loadChapter(chapter.filename).words
        guard !words.isEmpty else { return }

        var generated: [ReviewQuestion] = []

        // 3 multiple choice questions
        let mcWords = words.shuffled().prefix(3)
        for word in mcWords {
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

        // 2 fill-gap questions
        let fgWords = words.shuffled().prefix(2)
        for word in fgWords {
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
            showResults = true
        }
    }

    private func handleCompletion() {
        let score = Double(correctCount) / Double(questions.count)
        let passed = score >= progressManager.passingThreshold(for: currentProgress)
        onCompletion(passed, score)
    }
}

// MARK: – Subviews

struct ReviewQuestionView: View {
    let question: ReviewQuestion
    @Binding var selectedOption: String?
    @Binding var answered: Bool

    var body: some View {
        VStack(spacing: 20) {
            if question.type == .multipleChoice {
                Text("What does “\(question.italian)” mean?")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
            } else if question.type == .fillGap, let s = question.sentence {
                Text(s)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
            }

            ForEach(question.options, id: \.self) { option in
                Button(action: {
                    guard !answered else { return }
                    selectedOption = option
                    answered = true
                }) {
                    HStack {
                        Text(option)
                            .font(.body)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .fill(color(for: option))
                    )
                    .foregroundColor(.white)
                }
                .disabled(answered)
            }
        }
        .animation(.easeInOut, value: answered)
    }

    private func color(for option: String) -> Color {
        guard answered else { return Color.gray.opacity(0.6) }
        if option == question.correctAnswer {
            return Color.green
        } else if option == selectedOption {
            return Color.red
        } else {
            return Color.gray.opacity(0.4)
        }
    }
}

// MARK: – Result View

struct ReviewResultView: View {
    let correctCount: Int
    let total: Int
    let progress: Double
    let onContinue: () -> Void
    private let progressManager = ProgressManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            let score = Double(correctCount) / Double(total)
            let passed = score >= progressManager.passingThreshold(for: progress)

            Text(passed ? "✅ Great work!" : "🔁 Needs review")
                .font(.largeTitle.bold())

            Text("You got \(correctCount) of \(total) correct.")
                .font(.title3)
                .foregroundColor(.secondary)

            Text(String(format: "Score: %.0f%%",
                        score * 100,
                        progressManager.passingThreshold(for: progress) * 100))
                .font(.headline)

            Spacer()

            Button(action: onContinue) {
                Text(passed ? "Continue" : "Retry later")
                    .font(.headline)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(passed ? Color.green : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: – Supporting Model

enum ReviewQuestionType: String, Codable {
    case multipleChoice
    case fillGap
}

struct ReviewQuestion: Identifiable, Codable {
    var id = UUID()
    var type: ReviewQuestionType
    var italian: String
    var correctAnswer: String
    var options: [String]
    var sentence: String?
}
