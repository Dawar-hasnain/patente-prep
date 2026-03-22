//
//  WordLearningView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//  Redesigned — swipe navigation, card transitions, audio, new layout.
//

import SwiftUI

// MARK: - Swipe Direction

private enum SwipeDirection { case forward, backward }

// MARK: - WordLearningView

struct WordLearningView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: LearningViewModel

    let currentChapter: ChapterList
    var lessonIndex: Int = 0

    // ── Core UI state ──────────────────────────────────────────────────────
    @State private var flipped          = false
    @State private var isLearned        = false
    @State private var selectedExample: Example?

    // ── Session state ──────────────────────────────────────────────────────
    @State private var showReviewSession  = false
    @State private var showCompletion     = false
    @State private var currentProgress: Double = 0.0

    // ── Card transition state ──────────────────────────────────────────────
    @State private var cardOffset:    CGFloat = 0
    @State private var cardOpacity:   Double  = 1
    @State private var swipeDir: SwipeDirection = .forward

    // ── "Got it!" button state ─────────────────────────────────────────────
    @State private var showGotItFeedback = false

    // ── Swipe gesture tracking ─────────────────────────────────────────────
    @State private var dragOffset: CGFloat = 0

    private let progressManager = ProgressManager.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ─────────────────────────────────────────────────
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                // ── Progress bar ───────────────────────────────────────────
                chapterProgressBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                Spacer(minLength: 0)

                // ── Word card ──────────────────────────────────────────────
                WordCardView(word: viewModel.currentWord, flipped: $flipped)
                    .offset(x: cardOffset + dragOffset)
                    .opacity(cardOpacity)
                    .gesture(swipeGesture)

                Spacer(minLength: 12)

                // ── Context sentence (reveals on flip) ─────────────────────
                if flipped, let example = selectedExample {
                    contextCard(example)
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 20)

                // ── Navigation hint ────────────────────────────────────────
                swipeHint

                Spacer(minLength: 16)

                // ── Got it! CTA ────────────────────────────────────────────
                gotItButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: flipped)
        .onAppear { setupCurrentWord() }
        .onChange(of: viewModel.currentIndex) { _ in animateCardIn() }

        // ── Duolingo-style review session ──────────────────────────────────
        .fullScreenCover(isPresented: $showReviewSession) {
            let wordsToReview = viewModel.recentlyLearned.isEmpty
                ? viewModel.words.filter { viewModel.learnedWords.contains($0.italian) }
                : viewModel.recentlyLearned
            LessonSessionView(
                sessionWords: wordsToReview.isEmpty ? viewModel.words : wordsToReview,
                allWords: viewModel.words,
                onFinish: { handleReviewCompletion() }
            )
        }

        // ── Chapter completion sheet ───────────────────────────────────────
        .sheet(isPresented: $showCompletion) {
            CompletionView(
                currentChapter: currentChapter,
                totalWords: viewModel.words.count,
                onDismiss: { dismiss() },
                onNextChapter: handleNextChapter
            )
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Back button
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.secondary.opacity(0.1)))
            }

            Spacer()

            // Chapter title
            Text(currentChapter.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Word counter
            Text("\(viewModel.currentIndex + 1) / \(viewModel.words.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Chapter Progress Bar

    private var chapterProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * learnedFraction)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.learnedWords.count)
            }
        }
        .frame(height: 6)
    }

    private var learnedFraction: CGFloat {
        guard !viewModel.words.isEmpty else { return 0 }
        return CGFloat(viewModel.learnedWords.count) / CGFloat(viewModel.words.count)
    }

    // MARK: - Context Card

    private func contextCard(_ example: Example) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Used in context", systemImage: "text.bubble")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            Text(""\(example.sentence)"")
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Swipe Hint

    private var swipeHint: some View {
        HStack(spacing: 6) {
            if viewModel.currentIndex > 0 {
                Image(systemName: "arrow.left")
                    .font(.caption2)
                Text("Previous")
                    .font(.caption2)
            }
            Spacer()
            if viewModel.currentIndex < viewModel.words.count - 1 {
                Text("Next")
                    .font(.caption2)
                Image(systemName: "arrow.right")
                    .font(.caption2)
            }
        }
        .foregroundColor(.secondary.opacity(0.4))
        .padding(.horizontal, 36)
    }

    // MARK: - Got It! Button

    private var gotItButton: some View {
        Button {
            triggerGotItFeedback()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: showGotItFeedback ? "checkmark.circle.fill" : "hand.thumbsup.fill")
                    .font(.body.weight(.semibold))
                Text(isLearned ? "Move On" : "Got it!")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(showGotItFeedback ? Color.green : (isLearned ? Color.accentColor : Color.green))
                    .shadow(color: Color.green.opacity(0.3), radius: 8, y: 4)
            )
            .scaleEffect(showGotItFeedback ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showGotItFeedback)
        }
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                let h = value.translation.width
                let v = value.translation.height
                // Only track clearly horizontal swipes
                guard abs(h) > abs(v) else { return }
                dragOffset = h * 0.38   // rubber-band resistance
            }
            .onEnded { value in
                let h = value.translation.width
                let predictedH = value.predictedEndTranslation.width
                let threshold: CGFloat = 70

                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    dragOffset = 0
                }

                if h < -threshold || predictedH < -threshold * 2 {
                    // Swipe left → next word (browse without marking)
                    guard viewModel.currentIndex < viewModel.words.count - 1 else { return }
                    swipeDir = .forward
                    animateCardOut { viewModel.nextWord() }

                } else if h > threshold || predictedH > threshold * 2 {
                    // Swipe right → previous word
                    guard viewModel.currentIndex > 0 else { return }
                    swipeDir = .backward
                    animateCardOut { viewModel.previousWord() }
                }
            }
    }

    // MARK: - Card Animations

    /// Animate the current card out, execute `change`, then animate new card in.
    private func animateCardOut(change: @escaping () -> Void) {
        let exitX: CGFloat = swipeDir == .forward ? -UIScreen.main.bounds.width * 0.55
                                                   :  UIScreen.main.bounds.width * 0.55
        withAnimation(.easeIn(duration: 0.18)) {
            cardOffset  = exitX
            cardOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.19) {
            change()
            // Position off-screen on the opposite side before animating in
            cardOffset = -exitX
        }
        // animateCardIn() is called via onChange(of: currentIndex)
    }

    /// Slide new card in from the edge determined by swipeDir.
    private func animateCardIn() {
        setupCurrentWord()
        // cardOffset is already set to the entry position by animateCardOut
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            cardOffset  = 0
            cardOpacity = 1
        }
    }

    // MARK: - Got It! Logic

    private func triggerGotItFeedback() {
        HapticsManager.success()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            showGotItFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showGotItFeedback = false
            swipeDir = .forward
            markAsLearnedTapped()
        }
    }

    // MARK: - Core Logic (unchanged)

    private func setupCurrentWord() {
        flipped     = false
        isLearned   = viewModel.learnedWords.contains(viewModel.currentWord.italian)
        selectedExample = viewModel.currentWord.examples?.randomElement()
    }

    private func markAsLearnedTapped() {
        // Capture BEFORE markAsLearned() advances the index
        let learnedItalian  = viewModel.currentWord.italian
        let wasLastWord     = viewModel.currentIndex == viewModel.words.count - 1

        isLearned = true
        viewModel.markAsLearned()    // advances currentIndex internally

        ProgressManager.shared.logDailyLearningActivity()
        ProgressManager.shared.updateStreak()
        NotificationCenter.default.post(name: .didLearnWord, object: nil)
        evaluateProgressAndTriggerReview()
        ProgressManager.shared.updateMemoryState(for: learnedItalian, correct: true)

        if wasLastWord {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !ProgressManager.shared.isChapterMastered(currentChapter) {
                    let finalReview = FinalChapterReviewView(chapter: currentChapter)
                    let host = UIHostingController(rootView: finalReview)
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = scene.windows.first {
                        window.rootViewController = host
                        window.makeKeyAndVisible()
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.4)) { showCompletion = true }
                }
            }
        }
    }

    private func evaluateProgressAndTriggerReview() {
        currentProgress = Double(viewModel.learnedWords.count) / Double(viewModel.words.count)
        let sectionIndex = progressManager.currentSection(for: currentProgress)
        let checkpoints  = progressManager.reviewCheckpoints(for: currentChapter)
        guard sectionIndex < checkpoints.count else { return }
        if !checkpoints[sectionIndex].completed {
            showReviewSession = true
        }
    }

    private func handleReviewCompletion() {
        let sectionIndex = progressManager.currentSection(for: currentProgress)
        progressManager.updateCheckpoint(
            for: currentChapter,
            section: sectionIndex + 1,
            passed: true,
            score: 1.0
        )
        showReviewSession = false
    }

    private func handleNextChapter() {
        showCompletion = false
        guard let idx = ChapterList.allCases.firstIndex(of: currentChapter),
              idx + 1 < ChapterList.allCases.count else { return }
        let next = ChapterList.allCases[idx + 1]
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let root = UIHostingController(
                rootView: WordLearningView(
                    viewModel: LearningViewModel(words: loadChapter(next.filename).words),
                    currentChapter: next
                )
            )
            window.rootViewController = root
            window.makeKeyAndVisible()
        }
    }
}
