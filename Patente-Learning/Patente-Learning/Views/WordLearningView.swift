//
//  WordLearningView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//

import SwiftUI

struct WordLearningView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: LearningViewModel

    // Main states
    @State private var showCompletion = false
    @State private var isLearned = false
    @State private var flipped = false
    @State private var selectedExample: Example?
    @State private var showNewReview = false

    // Quiz state
    @State private var showQuiz = false

    // Lesson completion state
    @State private var showLessonCompletion = false
    @State private var lessonCorrectAnswers = 0      // quiz correct count this session
    @State private var wordsAlreadyLearned  = 0      // words learned before this session opened
    @State private var nextLessonToLaunch: Lesson? = nil
    @State private var isTransitioningToCompletion = false  // blocks re-render on last word

    // Review flow
    @State private var showReviewSession = false
    @State private var activeCheckpoint: ReviewCheckpoint? = nil
    @State private var currentProgress: Double = 0.0

    // Gesture
    @State private var dragOffset: CGFloat = 0.0

    private let progressManager = ProgressManager.shared
    let currentChapter: ChapterList
    var lessonIndex: Int? = nil     // nil = legacy full-chapter mode

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 25) {

                // ── Progress Header ───────────────────────────────────────
                WordLearningHeader(
                    currentIndex: viewModel.currentIndex,
                    total: viewModel.words.count,
                    lessonIndex: lessonIndex
                )
                .padding(.horizontal)

                // ── Word Card ─────────────────────────────────────────────
                WordCardView(word: viewModel.currentWord, flipped: $flipped)
                    .offset(x: dragOffset * 0.25)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 80
                                if value.translation.width < -threshold {
                                    HapticsManager.lightTap()
                                    nextWord()
                                } else if value.translation.width > threshold {
                                    HapticsManager.lightTap()
                                    previousWord()
                                }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                    )

                // ── Word Type ─────────────────────────────────────────────
                if let type = viewModel.currentWord.type {
                    Text(type.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // ── Context Sentence (shown after flip) ───────────────────
                if flipped, let example = selectedExample {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Used in context:")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.secondary)

                        Text("\"\(example.sentence)\"")
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 2)

                        Text(example.label.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(example.label == "vero"
                                          ? Color(UIColor.systemGreen)
                                          : Color(UIColor.systemRed))
                            )
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .padding()
                    .glassCard()
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // ── Action Buttons ────────────────────────────────────────
                HStack(spacing: 16) {

                    // Previous
                    Button(action: previousWord) {
                        Label("Previous", systemImage: "arrow.left")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .disabled(viewModel.currentIndex == 0)

                    // ── Challenge Button (replaces "Mark as Learned") ─────
                    if isLearned {
                        // Word already learned — plain next button
                        Button(action: nextWord) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Next Word")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    } else {
                        // Word not yet learned — launch the quiz challenge
                        Button {
                            HapticsManager.lightTap()
                            showQuiz = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "brain.head.profile")
                                Text("I Know This")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.top, 10)

                // ── Hint label ────────────────────────────────────────────
                if !isLearned {
                    Text("Tap the card to reveal the translation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .padding(.top, 8)
            .onAppear {
                setupCurrentWord()
                // Track how many words were already learned before this session
                wordsAlreadyLearned = viewModel.learnedWords.count
            }
            .onChange(of: viewModel.currentIndex) { _ in
                // Don't reset state when we're showing lesson completion
                if !showLessonCompletion { setupCurrentWord() }
            }

            // ── Quiz Sheet ────────────────────────────────────────────────
            .sheet(isPresented: $showQuiz) {
                QuizCardView(
                    word: viewModel.currentWord,
                    allWords: viewModel.words,
                    onResult: { correct in
                        showQuiz = false
                        if correct { lessonCorrectAnswers += 1 }
                        // Small delay so the sheet dismisses before we proceed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            markAsLearnedTapped(knewIt: correct)
                        }
                    }
                )
                .presentationDetents([.fraction(0.6)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }

            // ── Review Session ────────────────────────────────────────────
            .fullScreenCover(isPresented: $showReviewSession) {
                BlurScaleTransition(isPresented: $showReviewSession) {
                    if let checkpoint = activeCheckpoint {
                        if checkpoint.section == 999 {
                            FinalChapterReviewView(chapter: currentChapter)
                        } else {
                            ReviewSessionView(
                                chapter: currentChapter,
                                currentProgress: currentProgress,
                                checkpoint: checkpoint,
                                onCompletion: handleReviewCompletion,
                                onDismiss: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showReviewSession = false
                                    }
                                }
                            )
                        }
                    }
                }
            }

            // ── New Review (every 8 words) ────────────────────────────────
            .fullScreenCover(isPresented: $showNewReview) {
                NewReviewSessionView(
                    words: viewModel.recentlyLearned,
                    onFinish: {
                        viewModel.recentlyLearned.removeAll()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showNewReview = false
                        }
                    }
                )
            }

            // ── Completion Sheet ──────────────────────────────────────────
            .sheet(isPresented: $showCompletion) {
                CompletionView(
                    currentChapter: currentChapter,
                    totalWords: viewModel.words.count,
                    onDismiss: { dismiss() },
                    onNextChapter: handleNextChapter
                )
            }

            // ── Lesson Completion ─────────────────────────────────────────
            .fullScreenCover(isPresented: $showLessonCompletion) {
                let nextLesson = LessonManager.nextLesson(for: currentChapter)
                // hasNext = there is an incomplete unlocked lesson after this one
                let hasNext = nextLesson != nil && nextLesson?.id != lessonIndex

                let wordsThisSession = max(viewModel.words.count - wordsAlreadyLearned, 1)
                LessonCompletionView(
                    chapter: currentChapter,
                    lessonIndex: lessonIndex ?? 0,
                    correctAnswers: lessonCorrectAnswers,
                    totalWords: wordsThisSession,
                    onContinue: {
                        isTransitioningToCompletion = false
                        showLessonCompletion = false
                        dismiss()
                    },
                    onNextLesson: hasNext ? {
                        isTransitioningToCompletion = false
                        nextLessonToLaunch = nextLesson
                        showLessonCompletion = false
                    } : nil
                )
            }
            // ── Next Lesson push (fires after completion cover dismisses) ─
            .background(
                NavigationLink(
                    destination: Group {
                        if let next = nextLessonToLaunch {
                            WordLearningView(
                                viewModel: LearningViewModel(words: next.words),
                                currentChapter: currentChapter,
                                lessonIndex: next.id
                            )
                        }
                    },
                    isActive: Binding(
                        get: { nextLessonToLaunch != nil },
                        set: { if !$0 { nextLessonToLaunch = nil } }
                    )
                ) { EmptyView() }
                .hidden()
            )
        }
    }

    // MARK: - Setup

    private func setupCurrentWord() {
        guard !showLessonCompletion else { return }
        flipped = false
        showQuiz = false
        isLearned = viewModel.learnedWords.contains(viewModel.currentWord.italian)

        if let examples = viewModel.currentWord.examples, !examples.isEmpty {
            selectedExample = examples.randomElement()
        } else {
            selectedExample = nil
        }
    }

    // MARK: - Navigation

    private func previousWord() {
        flipped = false
        viewModel.previousWord()
        setupCurrentWord()
    }

    private func nextWord() {
        flipped = false
        viewModel.nextWord()
        setupCurrentWord()
    }

    // MARK: - Mark as Learned
    private func markAsLearnedTapped(knewIt: Bool) {
        isLearned = true

        let wasLastWord = viewModel.currentIndex == viewModel.words.count - 1

        // ── Lesson mode ────────────────────────────────────────────────────
        // Handle ALL lesson words here — never fall through to the chapter path
        if lessonIndex != nil {
            // Persist the word as learned directly — no nextWord() call on last word
            let wordItalian = viewModel.currentWord.italian
            if wasLastWord {
                // Last word: save without advancing index
                viewModel.learnedWords.insert(wordItalian)
                viewModel.recentlyLearned.append(viewModel.currentWord)
                UserDefaults.standard.set(Array(viewModel.learnedWords), forKey: "learnedWords")
            } else {
                // Non-last word: normal save + advance
                viewModel.markAsLearned()
            }

            ProgressManager.shared.logDailyLearningActivity()
            ProgressManager.shared.updateStreak()
            ProgressManager.shared.updateMemoryState(for: wordItalian, correct: knewIt)

            if wasLastWord {
                let wordsThisSession = max(viewModel.words.count - wordsAlreadyLearned, 1)
                let isPerfect        = lessonCorrectAnswers == wordsThisSession
                XPManager.shared.award(.lessonCompleted(perfectScore: isPerfect))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showLessonCompletion = true
                }
            }
            return
        }

        // ── Full-chapter mode only ──────────────────────────────────────────
        viewModel.markAsLearned()

        ProgressManager.shared.logDailyLearningActivity()
        ProgressManager.shared.updateStreak()
        ProgressManager.shared.updateMemoryState(for: viewModel.currentWord.italian, correct: knewIt)

        if viewModel.recentlyLearned.count == 8 {
            showNewReview = true
            return
        }

        evaluateProgressAndTriggerReview()

        if viewModel.currentIndex == viewModel.words.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !ProgressManager.shared.isChapterMastered(currentChapter) {
                    activeCheckpoint = ReviewCheckpoint(
                        section: 999,
                        completed: false,
                        scheduledDate: nil,
                        lastScore: nil
                    )
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showReviewSession = true
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showCompletion = true
                    }
                }
            }
        }
    }

    // MARK: - Review Logic

    private func evaluateProgressAndTriggerReview() {
        let manager = ProgressManager.shared
        let progress = manager.progress(for: currentChapter)

        if progress < manager.minimumReviewThreshold(for: currentChapter) { return }

        if let lastReview = UserDefaults.standard.object(forKey: "lastReviewPopup") as? Date {
            if Date().timeIntervalSince(lastReview) < 1800 { return }
        }

        if let pending = manager.nextPendingCheckpoint(for: currentChapter),
           let scheduled = pending.scheduledDate,
           scheduled > Date() { return }

        if let pending = manager.nextPendingCheckpoint(for: currentChapter) {
            UserDefaults.standard.set(Date(), forKey: "lastReviewPopup")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                launchReview(checkpoint: pending)
            }
        }
    }

    private func launchReview(checkpoint: ReviewCheckpoint) {
        activeCheckpoint = checkpoint
        withAnimation(.easeInOut(duration: 0.25)) {
            showReviewSession = true
        }
    }

    private func handleReviewCompletion(passed: Bool, score: Double) {
        progressManager.updateCheckpoint(
            for: currentChapter,
            section: activeCheckpoint?.section ?? 0,
            passed: passed,
            score: score
        )
        showReviewSession = false
    }

    // MARK: - Next Chapter
    // With lesson-based navigation the user returns to the map after
    // completing a lesson. "Continue to next chapter" from CompletionView
    // simply dismisses back to ChapterPathView where the next chapter node
    // is waiting to be tapped.
    private func handleNextChapter() {
        showCompletion = false
        dismiss()
    }
}

// MARK: - Header View

struct WordLearningHeader: View {
    let currentIndex: Int
    let total: Int
    var lessonIndex: Int? = nil

    @State private var animateBar = false

    var progress: Double {
        total == 0 ? 0 : Double(currentIndex + 1) / Double(total)
    }

    var label: String {
        if let lesson = lessonIndex {
            return "Lesson \(lesson + 1) · Word \(currentIndex + 1) of \(total)"
        }
        return "Word \(currentIndex + 1) of \(total)"
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(label)
                .font(.headline.weight(.medium))
                .foregroundColor(.secondary)
                .id(currentIndex)
                .transition(.opacity.combined(with: .move(edge: .top)))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * (animateBar ? progress : 0))
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: animateBar)
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
        }
        .onAppear { animateBar = true }
        .onChange(of: currentIndex) { _ in
            animateBar = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animateBar = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Word Learning – Lesson Mode") {
    WordLearningView(
        viewModel: LearningViewModel(words: [
            Words(
                italian: "abbagliare",
                english: "dazzle",
                type: "verb",
                examples: [Example(sentence: "I fari possono abbagliare gli altri.", label: "vero")]
            ),
            Words(italian: "corsia", english: "lane", type: "noun", examples: nil),
            Words(italian: "svolta", english: "turn", type: "noun", examples: nil)
        ]),
        currentChapter: .la_strada,
        lessonIndex: 0
    )
}

#Preview("Word Learning – Legacy Mode") {
    WordLearningView(
        viewModel: LearningViewModel(words: [
            Words(italian: "abbagliare", english: "dazzle", type: "verb", examples: nil),
            Words(italian: "corsia", english: "lane", type: "noun", examples: nil)
        ]),
        currentChapter: .la_strada
    )
}

#Preview("Header – Lesson Mode") {
    WordLearningHeader(currentIndex: 2, total: 8, lessonIndex: 1)
        .padding()
}

#Preview("Header – Legacy Mode") {
    WordLearningHeader(currentIndex: 14, total: 120)
        .padding()
}
