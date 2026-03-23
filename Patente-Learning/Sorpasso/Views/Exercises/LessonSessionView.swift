//
//  LessonSessionView.swift
//  Patente-Learning
//
//  The Duolingo-style session coordinator.
//  Replaces NewReviewSessionView and ReviewSessionView for all lesson flows.
//
//  Flow
//  ────
//  1. Build exercise queue via SessionBuilder (ExerciseEngine.swift)
//  2. Show cards one by one with slide transitions
//  3. Wrong answers cost a heart and are re-queued at the end of the deck
//  4. SessionFailedView when hearts == 0
//  5. LessonCompleteScreen when queue is exhausted
//  6. Awards XP and updates WordMemoryState on every answer
//

import SwiftUI

// MARK: - LessonSessionView

struct LessonSessionView: View {

    // ── Inputs ────────────────────────────────────────────────────────────
    /// The subset of words this session covers (e.g. one lesson).
    let sessionWords: [Words]
    /// Full chapter word list — needed for building distractors.
    let allWords: [Words]
    /// When false the session calls onFinish directly without showing
    /// the LessonCompleteScreen. Use false for short in-lesson drills;
    /// true (default) for full chapter review and practice sessions.
    var showsCompletion: Bool = true
    let onFinish: () -> Void

    // ── Session state ─────────────────────────────────────────────────────
    @State private var queue: [ExerciseCard] = []
    @State private var currentIndex = 0
    @State private var hearts = HeartsManager.shared.currentHearts
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    @State private var showFailed = false
    @State private var showErrorReview = false
    @State private var showComplete = false

    // Wrong-answer log for the error review screen
    @State private var wrongAnswers: [Words] = []

    // Used to animate card transitions
    @State private var cardID = UUID()

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if showFailed {
                SessionFailedView(
                    onRetry: resetSession,
                    onDismiss: onFinish,
                    onRefillWithXP: HeartsManager.shared.canRefillWithXP ? {
                        HeartsManager.shared.refillWithXP()
                        hearts = HeartsManager.maxHearts
                        showFailed = false
                    } : nil
                )
                .transition(.opacity)

            } else if showErrorReview {
                ErrorReviewScreen(wrongAnswers: wrongAnswers) {
                    withAnimation { showErrorReview = false; showComplete = true }
                }
                .transition(.opacity)

            } else if showComplete {
                LessonCompleteScreen(
                    correctCount: correctCount,
                    total: totalAnswered,
                    onContinue: onFinish
                )
                .transition(.opacity)

            } else if queue.isEmpty {
                ProgressView("Preparing lesson…")
                    .onAppear(perform: buildQueue)

            } else {
                VStack(spacing: 0) {
                    // ── Header: progress bar + hearts ─────────────────────
                    sessionHeader
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // ── Exercise Card ─────────────────────────────────────
                    exerciseCard(for: queue[currentIndex])
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
        .animation(.easeInOut(duration: 0.25), value: showErrorReview)
        .animation(.easeInOut(duration: 0.25), value: showComplete)
        .animation(.easeInOut(duration: 0.22), value: cardID)
    }

    // MARK: - Header

    private var sessionHeader: some View {
        HStack(spacing: 12) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * sessionProgress)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentIndex)
                }
            }
            .frame(height: 8)

            // Hearts
            HeartsView(hearts: hearts)
        }
        .frame(height: 24)
    }

    private var sessionProgress: CGFloat {
        guard !queue.isEmpty else { return 0 }
        return CGFloat(currentIndex) / CGFloat(queue.count)
    }

    // MARK: - Exercise Card Router

    @ViewBuilder
    private func exerciseCard(for card: ExerciseCard) -> some View {
        switch card {

        case .tapThePairs(let pairs):
            TapThePairsView(pairs: pairs) { _ in
                // Pairs don't cost hearts — just advance
                advance(correct: true, word: nil, isTapThePairs: true)
            }

        case .whatDoesItMean(let word, let choices):
            MultipleChoiceCardView(
                mode: .whatDoesItMean,
                word: word,
                choices: choices,
                onResult: { correct in advance(correct: correct, word: word) }
            )

        case .howDoYouSay(let word, let choices):
            MultipleChoiceCardView(
                mode: .howDoYouSay,
                word: word,
                choices: choices,
                onResult: { correct in advance(correct: correct, word: word) }
            )

        case .trueFalse(let word, let displayedTranslation, let isCorrect):
            TrueFalseCardView(
                word: word,
                displayedTranslation: displayedTranslation,
                isCorrect: isCorrect,
                onResult: { correct in advance(correct: correct, word: word) }
            )

        case .wordBank(let word, let bank):
            WordBankCardView(
                word: word,
                bank: bank,
                onResult: { correct in advance(correct: correct, word: word) }
            )

        case .fillInTheBlank(let word, let maskedSentence, let choices):
            FillInTheBlankCardView(
                word: word,
                maskedSentence: maskedSentence,
                choices: choices,
                onResult: { correct in advance(correct: correct, word: word) }
            )
        }
    }

    // MARK: - Session Logic

    private func advance(correct: Bool, word: Words?, isTapThePairs: Bool = false) {
        if let w = word {
            // Update memory state for every word-level answer
            ProgressManager.shared.updateMemoryState(for: w.italian, correct: correct)
            totalAnswered += 1
            if correct {
                correctCount += 1
            }
        }

        if !correct && !isTapThePairs {
            // Track for error review
            if let w = word { wrongAnswers.append(w) }

            hearts = max(0, hearts - 1)
            if hearts == 0 {
                HeartsManager.shared.depleteAll()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation { showFailed = true }
                }
                return
            }
            // Re-queue wrong answer near the end of the remaining deck
            if let wrongCard = queue[safe: currentIndex] {
                let insertAt = min(currentIndex + 3, queue.count)
                queue.insert(wrongCard, at: insertAt)
            }
        }

        // Advance to next card
        if currentIndex + 1 < queue.count {
            withAnimation {
                currentIndex += 1
                cardID = UUID()
            }
        } else {
            // Award XP if majority correct
            if totalAnswered > 0 {
                let accuracy = Double(correctCount) / Double(totalAnswered)
                if accuracy >= 0.5 {
                    XPManager.shared.award(.reviewPassed)
                }
            }
            // Persist remaining hearts
            HeartsManager.shared.save(hearts: hearts)

            if showsCompletion {
                if !wrongAnswers.isEmpty {
                    withAnimation { showErrorReview = true }
                } else {
                    withAnimation { showComplete = true }
                }
            } else {
                onFinish()
            }
        }
    }

    // MARK: - Queue Builder

    private func buildQueue() {
        let states = Dictionary(
            uniqueKeysWithValues: ProgressManager.shared.allMemoryStates()
                .map { ($0.word, $0) }
        )
        let builder = SessionBuilder(
            allWords: allWords,
            sessionWords: sessionWords,
            memoryStates: states
        )
        queue = builder.buildQueue()
    }

    private func resetSession() {
        hearts = HeartsManager.shared.currentHearts
        currentIndex = 0
        correctCount = 0
        totalAnswered = 0
        wrongAnswers  = []
        showFailed = false
        showErrorReview = false
        showComplete = false
        cardID = UUID()
        queue = []
        buildQueue()
    }
}

// MARK: - Lesson Complete Screen

private struct LessonCompleteScreen: View {
    let correctCount: Int
    let total: Int
    let onContinue: () -> Void

    @State private var scaleIn = false
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 80

    private var accuracy: Double {
        total > 0 ? Double(correctCount) / Double(total) : 1.0
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.green)
                    .scaleEffect(scaleIn ? 1 : 0.3)
                    .opacity(scaleIn ? 1 : 0)
            }
            .shadow(color: .green.opacity(0.2), radius: 20, y: 8)
            .padding(.bottom, 28)

            // Title
            Text("Lesson Complete!")
                .font(.system(.title, design: .rounded).weight(.bold))
                .padding(.bottom, 8)

            Text("\(correctCount) of \(total) correct · \(Int(accuracy * 100))%")
                .font(.title3)
                .foregroundColor(.secondary)
                .padding(.bottom, 48)

            // Accuracy bar
            VStack(spacing: 8) {
                HStack {
                    Text("Accuracy")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(accuracy * 100))%")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(accuracy >= 0.7 ? .green : .orange)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule()
                            .fill(accuracy >= 0.7 ? Color.green : Color.orange)
                            .frame(width: geo.size.width * CGFloat(accuracy))
                            .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.3), value: scaleIn)
                    }
                }
                .frame(height: 10)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)

            Spacer()

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
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                scaleIn = true
            }
            HapticsManager.success()
        }
    }
}

// MARK: - Error Review Screen

private struct ErrorReviewScreen: View {

    let wrongAnswers: [Words]
    let onContinue:  () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────────
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.orange)
                    .padding(.top, 52)

                Text("Review Your Mistakes")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .padding(.top, 8)

                Text("\(wrongAnswers.count) word\(wrongAnswers.count == 1 ? "" : "s") to brush up on")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 28)

            // ── Mistake cards ─────────────────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    // Deduplicate (same word can be wrong more than once per session)
                    ForEach(uniqueWords, id: \.italian) { word in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(word.italian)
                                    .font(.subheadline.weight(.bold))
                                Text(word.english)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button {
                                SpeechManager.shared.speak(word.italian)
                                HapticsManager.lightTap()
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.callout)
                                    .foregroundColor(.accentColor)
                                    .padding(8)
                                    .background(Circle().fill(Color.accentColor.opacity(0.1)))
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.orange.opacity(0.07))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 24)

            Button(action: onContinue) {
                Text("Got It — Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear { HapticsManager.lightTap() }
    }

    private var uniqueWords: [Words] {
        var seen  = Set<String>()
        var result = [Words]()
        for w in wrongAnswers where !seen.contains(w.italian) {
            seen.insert(w.italian)
            result.append(w)
        }
        return result
    }
}

// MARK: - Collection Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    LessonSessionView(
        sessionWords: [
            Words(italian: "corsia",    english: "lane",          type: "noun"),
            Words(italian: "freno",     english: "brake",         type: "noun"),
            Words(italian: "incrocio",  english: "junction",      type: "noun"),
            Words(italian: "semaforo",  english: "traffic light", type: "noun"),
        ],
        allWords: [
            Words(italian: "corsia",    english: "lane"),
            Words(italian: "freno",     english: "brake"),
            Words(italian: "incrocio",  english: "junction"),
            Words(italian: "semaforo",  english: "traffic light"),
            Words(italian: "strada",    english: "road"),
            Words(italian: "veicolo",   english: "vehicle"),
        ],
        onFinish: { print("Session finished") }
    )
}
