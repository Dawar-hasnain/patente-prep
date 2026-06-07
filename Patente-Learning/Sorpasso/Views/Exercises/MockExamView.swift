//
//  MockExamView.swift
//  Patente-Learning
//
//  Simulates the Italian driving theory exam using REAL ministry questions.
//
//  Rules (matching the real patente B format):
//    • 30 True / False questions sampled from the official bank (all chapters)
//    • Up to 3 incorrect answers are allowed; the exam fails on the 4th mistake
//    • Pass: ≤ 3 mistakes after all 30 questions
//    • Fail: 4 mistakes at any point → ExamFailedScreen
//
//  UX:
//    • Each question is the real Italian statement (tappable for per-word glosses)
//      with a "Show English" toggle revealing the full translation.
//    • Header: question counter (X / 30) + mistake-dot indicators + 30-min timer
//    • Error review shown on both pass and fail result screens
//

import SwiftUI
import Combine

// MARK: - Question Model

private struct ExamMistake: Identifiable {
    let id = UUID()
    let question: Question
    let userSaidTrue: Bool   // what the user tapped
}

private enum ExamFailReason {
    case tooManyMistakes
    case timeUp
}

// MARK: - MockExamView

struct MockExamView: View {

    let onFinish: () -> Void

    // ── Session state ─────────────────────────────────────────────────────
    @State private var questions:    [Question] = []
    @State private var currentIndex  = 0
    @State private var mistakes      = 0
    @State private var mistakeLog:   [ExamMistake] = []

    @State private var showFailed    = false
    @State private var failReason:   ExamFailReason = .tooManyMistakes
    @State private var showResult    = false
    @State private var cardID        = UUID()

    // ── 30-minute countdown ───────────────────────────────────────────────
    private static let examDuration: TimeInterval = 30 * 60   // 1800 s
    private static let questionCount = 30
    @State private var timeRemaining: TimeInterval = MockExamView.examDuration
    @State private var timerRunning  = false
    private let examClock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // ── Leave-exam confirmation ───────────────────────────────────────────
    @State private var showLeaveAlert = false

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if showFailed {
                ExamFailedScreen(
                    failReason: failReason,
                    mistakeLog: mistakeLog,
                    onRetry:    restartExam,
                    onExit:     onFinish
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
                    .onAppear {
                        buildQuestions()
                        timerRunning = true
                    }

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
        .onReceive(examClock) { _ in
            guard timerRunning, !showFailed, !showResult else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                failReason = .timeUp
                timerRunning = false
                withAnimation { showFailed = true }
                HapticsManager.error()
            }
        }
        .alert("Leave Exam?", isPresented: $showLeaveAlert) {
            Button("Leave", role: .destructive) { onFinish() }
            Button("Stay",  role: .cancel) { }
        } message: {
            Text("Your progress will not be saved.")
        }
    }

    // MARK: - Header

    private var examHeader: some View {
        VStack(spacing: 6) {
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

                // Mistake indicators — up to 3 errors are allowed; the 4th fails.
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Image(systemName: i < mistakes ? "xmark.circle.fill" : "circle")
                            .font(.body)
                            .foregroundColor(i < mistakes ? .red : Color.secondary.opacity(0.3))
                            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: mistakes)
                    }
                }
                .frame(width: 80, alignment: .trailing)
            }
            .frame(height: 36)

            // ── Countdown timer ────────────────────────────────────────────
            let isWarning = timeRemaining < 5 * 60   // < 5 minutes → red
            HStack(spacing: 5) {
                Image(systemName: isWarning ? "timer" : "clock")
                    .font(.caption.weight(.semibold))
                Text(formattedTime(timeRemaining))
                    .font(.subheadline.weight(.bold).monospacedDigit())
            }
            .foregroundColor(isWarning ? .red : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isWarning ? Color.red.opacity(0.1) : Color.secondary.opacity(0.08))
            )
            .animation(.easeInOut(duration: 0.3), value: isWarning)
        }
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Logic

    private func handleAnswer(userSaidTrue: Bool) {
        let question = questions[currentIndex]
        let correct  = (userSaidTrue == question.answer)

        ExamProgressManager.shared.record(question, correct: correct)

        if !correct {
            mistakes += 1
            mistakeLog.append(ExamMistake(
                question:     question,
                userSaidTrue: userSaidTrue
            ))
            HapticsManager.error()

            if mistakes >= 4 {
                timerRunning = false
                failReason   = .tooManyMistakes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation { showFailed = true }
                }
                return
            }
        } else {
            HapticsManager.success()
        }

        // Stop timer on last question before showing result
        if currentIndex + 1 >= questions.count { timerRunning = false }

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
                withAnimation { showResult = true }
            }
        }
    }

    // MARK: - Question Builder

    private func buildQuestions() {
        let pool = BloccoStore.shared.allQuestions
        questions = Array(pool.shuffled().prefix(Self.questionCount))
    }

    private func restartExam() {
        currentIndex  = 0
        mistakes      = 0
        mistakeLog    = []
        showFailed    = false
        showResult    = false
        cardID        = UUID()
        timeRemaining = MockExamView.examDuration
        timerRunning  = false
        questions     = []
        buildQuestions()
        timerRunning  = true
    }
}

// MARK: - ExamQuestionCard

/// True/False card for the mock exam, showing a real ministry statement.
/// Shows brief feedback overlay, then auto-advances — no extra tap required.
private struct ExamQuestionCard: View {

    let question: Question
    let onAnswer: (Bool) -> Void

    @State private var answered       = false
    @State private var userWasCorrect = false
    @State private var showOverlay    = false
    @State private var showEnglish    = false

    var body: some View {
        VStack(spacing: 0) {

            Text("True or False?")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .padding(.top, 28)
                .padding(.bottom, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // ── Statement card ────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        TappableSentenceView(sentence: question.text)

                        Button {
                            withAnimation { showEnglish.toggle() }
                        } label: {
                            Label(showEnglish ? "Hide English" : "Show English",
                                  systemImage: "character.bubble")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)

                        if showEnglish {
                            Text(question.text_en)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(.opacity)
                        }
                    }
                    .padding(.vertical, 22)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                }
            }

            Spacer(minLength: 24)

            // ── Buttons ───────────────────────────────────────────────────
            if !answered {
                HStack(spacing: 14) {
                    examButton(label: "VERO",  icon: "checkmark", color: .green, userSaidTrue: true)
                    examButton(label: "FALSO", icon: "xmark",     color: .red,   userSaidTrue: false)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: answered)
    }

    @ViewBuilder
    private func examButton(label: String, icon: String, color: Color, userSaidTrue: Bool) -> some View {
        Button {
            guard !answered else { return }
            let correct = (userSaidTrue == question.answer)
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

    let failReason: ExamFailReason
    let mistakeLog: [ExamMistake]
    let onRetry:    () -> Void
    let onExit:     () -> Void

    @State private var scaleIn = false

    private var icon:     String { failReason == .timeUp ? "timer"         : "xmark.seal.fill" }
    private var title:    String { failReason == .timeUp ? "Time's Up!"    : "Exam Failed" }
    private var subtitle: String {
        switch failReason {
        case .timeUp:           return "The 30-minute limit was reached.\nReview the questions below and try again."
        case .tooManyMistakes:  return "4 mistakes reached — the exam ended early.\nReview the questions below and try again."
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Icon ──────────────────────────────────────────────────
                ZStack {
                    Circle().fill(Color.red.opacity(0.1)).frame(width: 130, height: 130)
                    Image(systemName: icon)
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                        .scaleEffect(scaleIn ? 1 : 0.3)
                        .opacity(scaleIn ? 1 : 0)
                }
                .shadow(color: .red.opacity(0.2), radius: 16, y: 8)
                .padding(.top, 48)
                .padding(.bottom, 20)

                Text(title)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .padding(.bottom, 8)

                Text(subtitle)
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
                    HStack(alignment: .top, spacing: 14) {
                        // Red X icon
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.question.text)
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(m.question.text_en)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Correct answer: \(m.question.answer ? "VERO (True)" : "FALSO (False)")  ·  You said \(m.userSaidTrue ? "VERO" : "FALSO")")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.red.opacity(0.85))
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
