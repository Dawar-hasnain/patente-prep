//
//  RecallModeView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//

import SwiftUI

struct RecallModeView: View {
    let chapter: ChapterList
    @Environment(\.dismiss) private var dismiss

    @State private var questions: [RecallQuestion]
    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var score = 0
    @State private var finished = false
    @State private var showFeedback = false
    @State private var isCorrect = false
    @State private var shake = false
    @State private var scoreChange = false

    init(chapter: ChapterList) {
        self.chapter = chapter
        let words = loadChapter(chapter.filename).words
        _questions = State(initialValue: LearningViewModel(words: words).generateRecallQuestions(from: words))
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 25) {

                // ── Top Bar ───────────────────────────────────────────────
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("Recall Practice")
                            .font(.headline.weight(.semibold))
                        Text("Score: \(score)/\(questions.count)")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                            .scaleEffect(scoreChange ? 1.15 : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: scoreChange)
                    }

                    Spacer()

                    Text("\(currentIndex + 1)/\(questions.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                if !finished {
                    // ── Question ──────────────────────────────────────────
                    VStack(spacing: 20) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(showFeedback
                                              ? (isCorrect ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                              : Color.clear)
                                        .animation(.easeInOut(duration: 0.3), value: showFeedback)
                                )

                            VStack(spacing: 10) {
                                Text(questions[currentIndex].sentence)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal)

                                if showFeedback {
                                    Text(isCorrect ? "✅ Correct!" : "❌ Incorrect — \(questions[currentIndex].answer)")
                                        .font(.headline.weight(.medium))
                                        .foregroundColor(isCorrect ? .green : .red)
                                        .transition(.opacity)
                                }
                            }
                            .padding()
                        }
                        .padding(.horizontal)

                        TextField("Your answer...", text: $userAnswer)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 40)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .modifier(ShakeEffect(animatableData: CGFloat(shake ? 1 : 0)))

                        Button(action: checkAnswer) {
                            Text("Submit")
                                .font(.headline)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // ── Result ────────────────────────────────────────────
                    VStack(spacing: 16) {
                        Text("Final Score: \(score)/\(questions.count)")
                            .font(.title.bold())
                        Text(resultMessage())
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Button("Done") { dismiss() }
                            .font(.headline)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Logic

    private func checkAnswer() {
        let trimmed = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            withAnimation(.default) { shake.toggle() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shake = false }
            return
        }

        let correct = trimmed.lowercased() == questions[currentIndex].answer.lowercased()
        isCorrect = correct
        showFeedback = true

        if correct {
            score += 1
            scoreChange.toggle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { scoreChange = false }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showFeedback = false
            userAnswer = ""
            if currentIndex < questions.count - 1 {
                currentIndex += 1
            } else {
                finished = true
            }
        }
    }

    private func resultMessage() -> String {
        switch Double(score) / Double(questions.count) {
        case 0.8...: return "Excellent recall! ⭐️"
        case 0.6..<0.8: return "Good job! Keep practicing 💪"
        default: return "Let's review these words again 🔁"
        }
    }
}


// MARK: - Preview

#Preview {
    RecallModeView(chapter: .la_strada)
}
