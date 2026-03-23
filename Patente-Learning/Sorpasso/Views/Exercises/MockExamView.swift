//
//  MockExamView.swift
//  Patente-Learning
//
//  Simulates the Italian driving theory exam.
//
//  Rules (matching real patente format, scaled to 30 Qs):
//    • 30 True / False questions drawn from ALL 10 chapter word lists
//    • Maximum 3 incorrect answers — the exam fails immediately on the 3rd mistake
//    • Pass: ≤ 2 mistakes after all 30 questions → awards 100 XP
//    • Fail: 3 mistakes at any point → ExamFailedScreen
//
//  UX:
//    • Quick-feedback card: coloured overlay appears on answer, auto-advances after 0.8 s
//    • Header: question counter (X / 30) + 3 mistake-dot indicators
//    • Error review shown on both pass and fail result screens
//

import SwiftUI

// MARK: - Question Model

private struct ExamQuestion: Identifiable {
    let id = UUID()
    let word: Words
    let displayedTranslation: String
    let isCorrect: Bool     // ground truth
}

private struct ExamMistake: Identifiable {
    let id = UUID()
    let word: Words
    let displayedTranslation: String
    let wasCorrect: Bool     // the ground truth
    let userSaidTrue: Bool   // what the user tapped
}

// MARK: - MockExamView

struct MockExamView: View {

    let onFinish: () -> Void

    // ── Session state ─────────────────────────────────────────────────────
    @State private var questions:    [ExamQuestion] = []
    @State private var currentIndex  = 0
    @State private var mistakes      = 0
    @State private var mistakeLog:   [ExamMistake] = []

    @State private var showFailed    = false
    @State private var showResult    = false
    @State private var cardID        = UUID()

    // ── Leave-exam confirmation ───────────────────────────────────────────
    @State private var showLeaveAlert = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if showFailed {
                ExamFailedScreen(
                    mistakeLog: mistakeLog,
                    onRetry: restartExam,
                    onExit:  onFinish
                )
                .transition(.opacity)

            } else if showResult {
                ExamResultScreen(
                    total:      questions.count,
                    mistakes:   mistakes,
                    mistakeLog: mistakeLog,
                    onContinue: onFinish
                )
                .transition(.opacity)

            } else if questions.isEmpty {
                ProgressView("Loading exam…")
                    .onAppear(perform: buildQuestions)

            } else {
                VStack(spacing: 0) {
                    examHeader
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                    ExamQuestionCard(
                        question: questions[currentIndex],
                        onAnswer: { userSaidTrue in
                            handleAnswer(userSaidTrue: userSaidTrue)
                        }
                    )
                    .id(cardID)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        )
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showFailed)
        .animation(.easeInOut(duration: 0.25), value: showResult)
        .animation(.easeInOut(duration: 0.22), value: cardID)
        .alert("Leave Exam?", isPresented: $showLeaveAlert) {
            Button("Leave", role: .destructive) { onFinish() }
            Button("Stay",  role: .cancel) { }
        } message: {
            Text("Your progress will not be saved.")
        }
    }

    // MARK: - Header

    private var examHeader: some View {
        HStack(spacing: 0) {
            // Exit button
            Button {
                showLeaveAlert = true
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(8)
            }

            Spacer()

            // Question counter
            Text("\(currentIndex + 1) / \(questions.count)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(.primary)

            Spacer()

            // 3 mistake indicators
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < mistakes ? "xmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundColor(i < mistakes ? .red : Color.secondary.opacity(0.3))
                        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: mistakes)
                }
            }
            .frame(width: 80, alignment: .trailing)  // match exit button width for centering
        }
        .frame(height: 36)
    }

    // MARK: - Logic

    private func handleAnswer(userSaidTrue: Bool) {
        let question = questions[currentIndex]
        let correct  = (userSaidTrue == question.isCorrect)

        if !correct {
            mistakes += 1
            mistakeLog.append(ExamMistake(
                word:                 question.word,
                displayedTranslation: question.displayedTranslation,
                wasCorrect:           question.isCorrect,
                userSaidTrue:         userSaidTrue
            ))
            HapticsManager.error()

            if mistakes >= 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation { showFailed = true }
                }
                return
            }
        } else {
            HapticsManager.success()
        }

        // Advance
        if currentIndex + 1 < questions.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation {
                    currentIndex += 1
                    cardID = UUID()
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                XPManager.shared.award(.mockExamPassed)
                withAnimation { showResult = true }
            }
        }
    }

    // MARK: - Question Builder

    private func buildQuestions() {
        let allWords = ChapterList.allCases.flatMap { loadChapter($0.filename).words }
        let pool     = allWords.shuffled()
        let selected = Array(pool.prefix(30))

        questions = selected.map { word in
            let showWrong = Bool.random()
            if showWrong,
               let impostor = pool.filter({ $0.italian != word.italian }).randomElement() {
                return ExamQuestion(
                    word:                 word,
                    displayedTranslation: impostor.english,
                    isCorrect:            false
                )
            } else {
                return ExamQuestion(
                    word:                 word,
                    displayedTranslation: word.english,
                    isCorrect:            true
                )
            }
        }
    }

    private func restartExam() {
        currentIndex = 0
        mistakes     = 0
        mistakeLog   = []
        showFailed   = false
        showResult   = false
        cardID       = UUID()
        questions    = []
        buildQuestions()
    }
}

// MARK: - ExamQuestionCard

/// Minimal True/False card for the mock exam.
/// Shows brief feedback overlay, then auto-advances — no tap required.
private struct ExamQuestionCard: View {

    let question: ExamQuestion
    let onAnswer: (Bool) -> Void

    @State private var answered       = false
    @State private var userWasCorrect = false
    @State private var showOverlay    = false

    var body: some View {
        VStack(spacing: 0) {

            Text("True or False?")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .padding(.top, 40)
                .padding(.bottom, 24)

            // ── Word card ─────────────────────────────────────────────────
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text(question.word.italian)
                        .font(.system(.title, design: .rounded).weight(.bold))
                    Button {
                        SpeechManager.shared.speak(question.word.italian)
                        HapticsManager.lightTap()
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.callout)
                            .foregroundColor(.accentColor)
                            .padding(8)
                            .background(Circle().fill(Color.accentColor.opacity(0.1)))
                    }
                }

                HStack(spacing: 10) {
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                    Text("means").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                }
                .padding(.horizontal, 40)

                Text(question.displayedTranslation)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondary.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
            )
            .overlay(
                // Feedback flash overlay
                RoundedRectangle(cornerRadius: 20)
                    .fill(userWasCorrect ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                    .opacity(showOverlay ? 1 : 0)
                    .animation(.easeOut(duration: 0.15), value: showOverlay)
            )
            .padding(.horizontal)

            Spacer(minLength: 48)

            // ── Buttons ───────────────────────────────────────────────────
            if !answered {
                HStack(spacing: 14) {
                    examButton(label: "TRUE",  icon: "checkmark", color: .green, userSaidTrue: true)
                    examButton(label: "FALSE", icon: "xmark",     color: .red,   userSaidTrue: false)
                }
                .padding(.horizontal)
                .padding(.bottom, 48)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: answered)
    }

    @ViewBuilder
    private func examButton(label: String, icon: String, color: Color, userSaidTrue: Bool) -> some View {
        Button {
            guard !answered else { return }
            let correct = (userSaidTrue == question.isCorrect)
            answered       = true
            userWasCorrect = correct
            showOverlay    = true
            onAnswer(userSaidTrue)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2.weight(.bold))
                Text(label).font(.headline.weight(.bold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.4), lineWidth: 2))
        }
        .disabled(answered)
    }
}

// MARK: - ExamResultScreen (Pass)

private struct ExamResultScreen: View {

    let total:      Int
    let mistakes:   Int
    let mistakeLog: [ExamMistake]
    let onContinue: () -> Void

    @State private var scaleIn = false

    private var correct: Int { total - mistakes }
    private var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 1.0 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Trophy ────────────────────────────────────────────────
                ZStack {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 140, height: 140)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.green)
                        .scaleEffect(scaleIn ? 1 : 0.3)
                        .opacity(scaleIn ? 1 : 0)
                }
                .shadow(color: .green.opacity(0.2), radius: 20, y: 8)
                .padding(.top, 48)
                .padding(.bottom, 20)

                Text("Exam Passed!")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .padding(.bottom, 6)

                Text("\(correct) / \(total) correct · \(mistakes) mistake\(mistakes == 1 ? "" : "s")")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)

                // XP badge
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").foregroundColor(.yellow)
                    Text(XPAward.mockExamPassed.label)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.yellow.opacity(0.15)))
                .padding(.bottom, 36)

                // ── Accuracy bar ──────────────────────────────────────────
                VStack(spacing: 8) {
                    HStack {
                        Text("Accuracy").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(accuracy * 100))%")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.green)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))
                            Capsule()
                                .fill(Color.green)
                                .frame(width: geo.size.width * CGFloat(accuracy))
                                .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.3), value: scaleIn)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)

                // ── Mistakes review ───────────────────────────────────────
                if !mistakeLog.isEmpty {
                    MistakeReviewSection(mistakes: mistakeLog)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.green))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { scaleIn = true }
            HapticsManager.success()
        }
    }
}

// MARK: - ExamFailedScreen

private struct ExamFailedScreen: View {

    let mistakeLog: [ExamMistake]
    let onRetry:    () -> Void
    let onExit:     () -> Void

    @State private var scaleIn = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Icon ──────────────────────────────────────────────────
                ZStack {
                    Circle().fill(Color.red.opacity(0.1)).frame(width: 130, height: 130)
                    Image(systemName: "xmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                        .scaleEffect(scaleIn ? 1 : 0.3)
                        .opacity(scaleIn ? 1 : 0)
                }
                .shadow(color: .red.opacity(0.2), radius: 16, y: 8)
                .padding(.top, 48)
                .padding(.bottom, 20)

                Text("Exam Failed")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .padding(.bottom, 8)

                Text("3 mistakes reached — the exam ended early.\nStudy the words below and try again.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)

                // ── Mistakes review ───────────────────────────────────────
                MistakeReviewSection(mistakes: mistakeLog)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)

                // ── Buttons ───────────────────────────────────────────────
                VStack(spacing: 14) {
                    Button(action: onRetry) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Try Again")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.red))
                        .foregroundColor(.white)
                    }

                    Button(action: onExit) {
                        Text("Back to Practice")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.1)))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { scaleIn = true }
            HapticsManager.heavyTap()
        }
    }
}

// MARK: - MistakeReviewSection

private struct MistakeReviewSection: View {
    let mistakes: [ExamMistake]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Review Mistakes", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                ForEach(mistakes) { m in
                    HStack(spacing: 14) {
                        // Red X icon
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(m.word.italian)
                                .font(.subheadline.weight(.bold))
                            Text("Correct: \(m.word.english)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if m.displayedTranslation != m.word.english {
                                Text("Shown: \"\(m.displayedTranslation)\" — this was FALSE")
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }

                        Spacer()

                        // Speak button
                        Button {
                            SpeechManager.shared.speak(m.word.italian)
                            HapticsManager.lightTap()
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.callout)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.red.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.red.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MockExamView(onFinish: {})
}
