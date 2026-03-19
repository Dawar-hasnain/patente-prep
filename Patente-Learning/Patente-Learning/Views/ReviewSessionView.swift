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
    let checkpoint: ReviewCheckpoint
    let onCompletion: (_ passed: Bool, _ score: Double) -> Void
    let onDismiss: () -> Void

    @State private var questions: [ReviewQuestion] = []
    @State private var currentIndex = 0
    @State private var correctCount = 0
    @State private var answered = false
    @State private var selectedOption: String? = nil
    @State private var showResults = false
    @State private var reviewDelayedUntil: Date? = nil
    @State private var passed = false
    @State private var hearts = 5          // ← Hearts system
    @State private var showFailed = false  // ← Session failed screen

    private let progressManager = ProgressManager.shared

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if showFailed {
                SessionFailedView(
                    onRetry: resetSession,
                    onDismiss: onDismiss
                )
            } else if showResults {
                ReviewResultView(
                    correctCount: correctCount,
                    total: questions.count,
                    progress: currentProgress,
                    onContinue: handleCompletion
                )
            } else if !questions.isEmpty {
                let q = questions[currentIndex]

                VStack(spacing: 24) {

                    // ── Header: progress + hearts ─────────────────
                    HStack {
                        Text("Review \(currentIndex + 1) of \(questions.count)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        HeartsView(hearts: hearts)
                    }
                    .padding(.horizontal)

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

                    if !passed {
                        Button("Not Now") {
                            let newTime = Date().addingTimeInterval(15 * 60)
                            ProgressManager.shared.deferCheckpoint(
                                chapter: chapter,
                                section: checkpoint.section,
                                until: newTime
                            )
                            onDismiss()
                        }
                        .padding()
                        .foregroundColor(.red)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.red))
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
        .animation(.easeInOut, value: showFailed)
    }

    // MARK: - Question Generation
    private func generateQuestions() {
        let words = loadChapter(chapter.filename).words
        guard !words.isEmpty else { return }

        var generated: [ReviewQuestion] = []

        // ── 3 Multiple Choice: Italian → English ──────────────────────────
        let mcWords = words.shuffled().prefix(3)
        for word in mcWords {
            let distractors = words
                .filter { $0.english != word.english }
                .shuffled()
                .prefix(3)
                .map { $0.english }
            let options = Array(Set(distractors + [word.english])).shuffled()
            generated.append(
                ReviewQuestion(
                    type: .multipleChoice,
                    italian: word.italian,
                    correctAnswer: word.english,
                    options: options,
                    sentence: nil
                )
            )
        }

        // ── 2 Fill-the-Gap ────────────────────────────────────────────────
        let fgWords = words.shuffled().prefix(2)
        for word in fgWords {
            if let example = word.examples?.first {
                let masked = example.sentence.replacingOccurrences(of: word.italian, with: "____")
                let distractors = words
                    .filter { $0.italian != word.italian }
                    .shuffled()
                    .prefix(3)
                    .map { $0.italian }
                let options = Array(Set(distractors + [word.italian])).shuffled()
                generated.append(
                    ReviewQuestion(
                        type: .fillGap,
                        italian: word.italian,
                        correctAnswer: word.italian,
                        options: options,
                        sentence: masked
                    )
                )
            }
        }

        // ── 2 True / False ────────────────────────────────────────────────
        // Pick words that have at least one example sentence
        let tfCandidates = words.filter { ($0.examples?.isEmpty == false) }
        let tfWords = tfCandidates.shuffled().prefix(2)
        for word in tfWords {
            if let example = word.examples?.randomElement() {
                generated.append(
                    ReviewQuestion(
                        type: .trueFalso,
                        italian: word.italian,
                        correctAnswer: example.label,   // "vero" or "falso"
                        options: [],                    // not used for T/F
                        sentence: example.sentence
                    )
                )
            }
        }

        questions = generated.shuffled()
    }

    // MARK: - Navigation
    private func nextQuestion() {
        guard let selected = selectedOption else { return }
        let correct = questions[currentIndex].correctAnswer
        let isCorrect = selected == correct

        if isCorrect {
            correctCount += 1
            HapticsManager.success()
        } else {
            hearts = max(0, hearts - 1)
            HapticsManager.error()
        }

        ProgressManager.shared.updateMemoryState(
            for: questions[currentIndex].italian,
            correct: isCorrect
        )

        // No hearts left — fail the session
        if hearts == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showFailed = true
            }
            return
        }

        if currentIndex < questions.count - 1 {
            currentIndex += 1
            answered = false
            selectedOption = nil
        } else {
            showResults = true
        }
    }

    private func resetSession() {
        hearts = 5
        currentIndex = 0
        correctCount = 0
        answered = false
        selectedOption = nil
        showFailed = false
        showResults = false
        questions = []
        generateQuestions()
    }

    private func handleCompletion() {
        let score = Double(correctCount) / Double(questions.count)
        let passed = score >= progressManager.passingThreshold(for: currentProgress)
        if passed { XPManager.shared.award(.reviewPassed) }
        if !passed { delayReview() }
        onCompletion(passed, score)
    }

    private func delayReview() {
        let delayTime = Date().addingTimeInterval(15 * 60)
        reviewDelayedUntil = delayTime
        UserDefaults.standard.set(delayTime, forKey: "nextReviewDue")
        showResults = false
    }
}

// MARK: - ReviewQuestionView

struct ReviewQuestionView: View {
    let question: ReviewQuestion
    @Binding var selectedOption: String?
    @Binding var answered: Bool

    var body: some View {
        VStack(spacing: 20) {
            switch question.type {

            // ── Multiple Choice ───────────────────────────────────────────
            case .multipleChoice:
                Text("What does \"\(question.italian)\" mean?")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                optionButtons(correct: question.correctAnswer)

            // ── Fill the Gap ──────────────────────────────────────────────
            case .fillGap:
                if let sentence = question.sentence {
                    Text(sentence)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                }

                optionButtons(correct: question.correctAnswer)

            // ── True / False ──────────────────────────────────────────────
            case .trueFalso:
                trueFalsoView
            }
        }
        .animation(.easeInOut, value: answered)
    }

    // MARK: Shared option buttons (MC + Fill-Gap)
    @ViewBuilder
    private func optionButtons(correct: String) -> some View {
        ForEach(question.options, id: \.self) { option in
            Button {
                guard !answered else { return }
                selectedOption = option
                answered = true
            } label: {
                HStack {
                    Text(option)
                        .font(.body)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(optionColor(option, correct: correct)))
                .foregroundColor(.white)
            }
            .disabled(answered)
        }
    }

    // MARK: True / False UI
    private var trueFalsoView: some View {
        VStack(spacing: 20) {
            // Label
            Text("La frase è vera o falsa?")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            // Sentence card
            if let sentence = question.sentence {
                Text("\"\(sentence)\"")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.1))
                    )
                    .padding(.horizontal)
            }

            // Vero / Falso buttons
            HStack(spacing: 16) {
                ForEach(["vero", "falso"], id: \.self) { choice in
                    Button {
                        guard !answered else { return }
                        selectedOption = choice
                        answered = true
                    } label: {
                        Text(choice.uppercased())
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(tfButtonColor(choice))
                            )
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(tfBorderColor(choice), lineWidth: 3)
                            )
                            .scaleEffect(answered && choice == question.correctAnswer ? 1.04 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: answered)
                    }
                    .disabled(answered)
                }
            }
            .padding(.horizontal)

            // Feedback label shown after answering
            if answered {
                let isCorrect = selectedOption == question.correctAnswer
                HStack(spacing: 8) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(isCorrect ? "Corretto!" : "La risposta giusta era: \(question.correctAnswer.uppercased())")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(isCorrect ? .green : .red)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    // MARK: - Color Helpers

    private func optionColor(_ option: String, correct: String) -> Color {
        guard answered else { return Color.gray.opacity(0.6) }
        if option == correct { return .green }
        if option == selectedOption { return .red }
        return Color.gray.opacity(0.4)
    }

    private func tfButtonColor(_ choice: String) -> Color {
        guard answered else {
            return choice == "vero" ? Color.green.opacity(0.75) : Color.red.opacity(0.75)
        }
        if choice == question.correctAnswer { return .green }
        if choice == selectedOption { return .red }
        return Color.gray.opacity(0.4)
    }

    private func tfBorderColor(_ choice: String) -> Color {
        guard answered else { return .clear }
        if choice == question.correctAnswer { return Color.green.opacity(0.8) }
        if choice == selectedOption { return Color.red.opacity(0.8) }
        return .clear
    }
}

// MARK: - ReviewResultView

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

            Text(String(format: "Score: %.0f%%", score * 100))
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

// MARK: - Supporting Models

enum ReviewQuestionType: String, Codable {
    case multipleChoice
    case fillGap
    case trueFalso           // ← NEW
}

struct ReviewQuestion: Identifiable, Codable {
    var id = UUID()
    var type: ReviewQuestionType
    var italian: String
    var correctAnswer: String  // "vero" / "falso" for T/F, english word for MC, italian word for fillGap
    var options: [String]      // empty for T/F
    var sentence: String?      // the example sentence (T/F + fillGap)
}

// MARK: - Preview

#Preview {
    ReviewSessionView(
        chapter: .la_strada,
        currentProgress: 0.4,
        checkpoint: ReviewCheckpoint(
            section: 1,
            completed: false,
            scheduledDate: nil,
            lastScore: nil
        ),
        onCompletion: { passed, score in
            print("Completed — passed: \(passed), score: \(score)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
}
