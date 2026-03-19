//
//  NewReviewSessionView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 30/11/25.
//

import SwiftUI

// MARK: - Question Model

struct NewReviewQuestion: Identifiable {
    let id = UUID()
    let type: NewReviewQuestionType
    let italian: String
    let english: String
    let options: [String]       // used for .multipleChoice only
    let sentence: String?       // used for .trueFalso only
    let correctAnswer: String   // english for MC; "vero"/"falso" for T/F
}

enum NewReviewQuestionType {
    case multipleChoice
    case trueFalso
}

// MARK: - Main View

struct NewReviewSessionView: View {
    let words: [Words]
    let onFinish: () -> Void

    @State private var questions: [NewReviewQuestion] = []
    @State private var currentIndex = 0
    @State private var selected: String? = nil
    @State private var answered = false
    @State private var correctCount = 0
    @State private var showResults = false
    @State private var shake = false
    @State private var animateCorrect = false
    @State private var hearts = 5
    @State private var showFailed = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if showFailed {
                SessionFailedView(
                    onRetry: resetSession,
                    onDismiss: onFinish
                )
            } else if showResults {
                resultScreen
            } else if !questions.isEmpty {
                reviewScreen
            } else {
                ProgressView("Preparing questions…")
                    .onAppear { generateQuestions() }
            }
        }
        .animation(.easeInOut, value: answered)
    }
}

// MARK: - Screens

extension NewReviewSessionView {

    // ── Review Screen ─────────────────────────────────────────────────────
    private var reviewScreen: some View {
        let q = questions[currentIndex]

        return VStack(spacing: 24) {
            // progress + hearts header
            HStack {
                progressBar
                HeartsView(hearts: hearts)
                    .padding(.leading, 8)
            }
            .padding(.horizontal)

            switch q.type {
            case .multipleChoice:
                multipleChoiceBody(q)
            case .trueFalso:
                trueFalsoBody(q)
            }

            if answered {
                Button(nextButtonTitle) { nextQuestion() }
                    .font(.headline)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .transition(.opacity)
            }

            Spacer()
        }
        .padding()
    }

    // ── Multiple Choice Body ──────────────────────────────────────────────
    @ViewBuilder
    private func multipleChoiceBody(_ q: NewReviewQuestion) -> some View {
        Text(q.italian)
            .font(.largeTitle.bold())
            .padding(.top, 20)
            .multilineTextAlignment(.center)

        VStack(spacing: 14) {
            ForEach(q.options, id: \.self) { option in
                mcOptionButton(option, correct: q.correctAnswer)
            }
        }
        .modifier(ShakeEffect(animatableData: shake ? 1 : 0))
    }

    // ── True / False Body ─────────────────────────────────────────────────
    @ViewBuilder
    private func trueFalsoBody(_ q: NewReviewQuestion) -> some View {
        Text("La frase è vera o falsa?")
            .font(.subheadline.weight(.medium))
            .foregroundColor(.secondary)

        if let sentence = q.sentence {
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

        HStack(spacing: 16) {
            ForEach(["vero", "falso"], id: \.self) { choice in
                Button {
                    guard !answered else { return }
                    handleTFSelection(choice: choice, correct: q.correctAnswer)
                } label: {
                    Text(choice.uppercased())
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(tfButtonColor(choice, correct: q.correctAnswer))
                        )
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(tfBorderColor(choice, correct: q.correctAnswer), lineWidth: 3)
                        )
                        .scaleEffect(answered && choice == q.correctAnswer ? 1.04 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: answered)
                }
                .disabled(answered)
            }
        }
        .padding(.horizontal)
        .modifier(ShakeEffect(animatableData: shake ? 1 : 0))

        if answered {
            let isCorrect = selected == q.correctAnswer
            HStack(spacing: 8) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                Text(isCorrect ? "Corretto!" : "Era: \(q.correctAnswer.uppercased())")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(isCorrect ? .green : .red)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // ── Progress Bar ──────────────────────────────────────────────────────
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * progress)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentIndex)
            }
        }
        .frame(height: 8)
        .padding(.horizontal)
    }

    private var progress: CGFloat {
        guard !questions.isEmpty else { return 0 }
        return CGFloat(currentIndex + 1) / CGFloat(questions.count)
    }

    // ── Result Screen ─────────────────────────────────────────────────────
    private var resultScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(correctCount >= questions.count / 2 ? "✅ Review Complete!" : "🔁 Keep Practicing!")
                .font(.largeTitle.bold())

            Text("Score: \(correctCount) / \(questions.count)")
                .font(.title2)
                .foregroundColor(.secondary)

            Spacer()

            Button("Continue") { onFinish() }
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Button Builders

extension NewReviewSessionView {

    @ViewBuilder
    private func mcOptionButton(_ option: String, correct: String) -> some View {
        Button {
            handleMCSelection(option: option, correct: correct)
        } label: {
            Text(option)
                .frame(maxWidth: .infinity)
                .padding()
                .background(mcButtonColor(option: option, correct: correct))
                .foregroundColor(.white)
                .cornerRadius(12)
                .opacity(answered && selected != option ? 0.6 : 1.0)
        }
        .disabled(answered)
    }

    private func mcButtonColor(option: String, correct: String) -> Color {
        if !answered { return Color.blue.opacity(0.7) }
        if option == correct { return .green }
        if option == selected { return .red }
        return Color.blue.opacity(0.5)
    }

    private func tfButtonColor(_ choice: String, correct: String) -> Color {
        guard answered else {
            return choice == "vero" ? Color.green.opacity(0.75) : Color.red.opacity(0.75)
        }
        if choice == correct { return .green }
        if choice == selected { return .red }
        return Color.gray.opacity(0.4)
    }

    private func tfBorderColor(_ choice: String, correct: String) -> Color {
        guard answered else { return .clear }
        if choice == correct { return Color.green.opacity(0.8) }
        if choice == selected { return Color.red.opacity(0.8) }
        return .clear
    }
}

// MARK: - Answer Handling & Question Generation

extension NewReviewSessionView {

    private func handleMCSelection(option: String, correct: String) {
        guard !answered else { return }
        selected = option
        answered = true
        if option == correct {
            correctCount += 1
            HapticsManager.success()
        } else {
            hearts = max(0, hearts - 1)
            HapticsManager.error()
            triggerShake()
            checkHeartsFailed()
        }
    }

    private func handleTFSelection(choice: String, correct: String) {
        guard !answered else { return }
        selected = choice
        answered = true
        if choice == correct {
            correctCount += 1
            HapticsManager.success()
        } else {
            hearts = max(0, hearts - 1)
            HapticsManager.error()
            triggerShake()
            checkHeartsFailed()
        }
    }

    private func checkHeartsFailed() {
        if hearts == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showFailed = true
            }
        }
    }

    private func resetSession() {
        hearts = 5
        currentIndex = 0
        correctCount = 0
        answered = false
        selected = nil
        showFailed = false
        showResults = false
        questions = []
        generateQuestions()
    }

    private func triggerShake() {
        withAnimation(.default) { shake = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shake = false }
    }

    private var nextButtonTitle: String {
        currentIndex == questions.count - 1 ? "Finish" : "Next"
    }

    private func nextQuestion() {
        if currentIndex == questions.count - 1 {
            showResults = true
            return
        }
        currentIndex += 1
        selected = nil
        answered = false
    }

    // ── Question Generation ───────────────────────────────────────────────
    private func generateQuestions() {
        guard words.count >= 2 else { return }

        var generated: [NewReviewQuestion] = []

        // Multiple Choice — up to 6 from the batch
        let mcWords = words.shuffled().prefix(6)
        for word in mcWords {
            let distractors = words
                .filter { $0.english != word.english }
                .shuffled()
                .prefix(3)
                .map { $0.english }
            let options = Array(Set(distractors + [word.english])).shuffled()
            generated.append(NewReviewQuestion(
                type: .multipleChoice,
                italian: word.italian,
                english: word.english,
                options: options,
                sentence: nil,
                correctAnswer: word.english
            ))
        }

        // True / False — up to 2 from words that have example sentences
        let tfCandidates = words.filter { $0.examples?.isEmpty == false }
        let tfWords = tfCandidates.shuffled().prefix(2)
        for word in tfWords {
            if let example = word.examples?.randomElement() {
                generated.append(NewReviewQuestion(
                    type: .trueFalso,
                    italian: word.italian,
                    english: word.english,
                    options: [],
                    sentence: example.sentence,
                    correctAnswer: example.label   // "vero" or "falso"
                ))
            }
        }

        questions = generated.shuffled()
    }
}
