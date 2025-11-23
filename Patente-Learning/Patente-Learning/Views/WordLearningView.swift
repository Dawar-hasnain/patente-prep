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

    @State private var showCompletion = false
    @State private var isLearned = false
    @State private var flipped = false
    @State private var selectedExample: Example?
    @State private var showReviewSession = false          // 🔹 new
    @State private var currentProgress: Double = 0.0      // 🔹 new

    private let progressManager = ProgressManager.shared  // 🔹 new
    let currentChapter: ChapterList

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 25) {

                // 🔹 Progress indicator
                Text("Word \(viewModel.currentIndex + 1) of \(viewModel.words.count)")
                    .font(.headline)
                    .foregroundColor(.secondary)

                // 🔹 Main Word Card
                WordCardView(word: viewModel.currentWord, flipped: $flipped)

                // 🔹 Type (noun, verb, adjective)
                if let type = viewModel.currentWord.type {
                    Text(type.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 🔹 Context sentence (only visible when flipped)
                if flipped, let example = selectedExample {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Used in context:")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.secondary)

                        Text("“\(example.sentence)”")
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
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

                // 🔹 Navigation controls
                HStack(spacing: 20) {
                    Button(action: previousWord) {
                        Label("Previous", systemImage: "arrow.left")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.currentIndex == 0)

                    Button(action: markAsLearnedTapped) {
                        HStack(spacing: 8) {
                            if !isLearned {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.headline)
                            }
                            Text(isLearned ? "Next Word" : "Mark as Learned")
                                .font(.headline)
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(isLearned ? Color.green.opacity(0.7) : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .animation(.easeInOut, value: isLearned)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .padding(.horizontal)
            .padding(.top, 8)
            .onAppear { setupCurrentWord() }
            .onChange(of: viewModel.currentIndex) { _ in setupCurrentWord() }

            // 🔹 REVIEW SESSION (appears when 10% milestone reached)
            .fullScreenCover(isPresented: $showReviewSession) {
                ReviewSessionView(
                    chapter: currentChapter,
                    currentProgress: currentProgress,
                    onCompletion: handleReviewCompletion
                )
            }

            // 🔹 Chapter completion sheet (same as before)
            .sheet(isPresented: $showCompletion) {
                CompletionView(
                    currentChapter: currentChapter,
                    totalWords: viewModel.words.count,
                    onDismiss: { dismiss() },
                    onNextChapter: handleNextChapter
                )
            }
        }
    }

    // MARK: - Logic Helpers
    private func setupCurrentWord() {
        flipped = false
        isLearned = viewModel.learnedWords.contains(viewModel.currentWord.italian)
        if let examples = viewModel.currentWord.examples, !examples.isEmpty {
            selectedExample = examples.randomElement()
        } else {
            selectedExample = nil
        }
    }

    private func markAsLearnedTapped() {
        // 🔸 Mark the word as learned locally
        isLearned = true
        viewModel.markAsLearned()
        
        // 🔹 Log today's activity for weekly chart
        ProgressManager.shared.logDailyLearningActivity()
        
        // 🔹 Update streak data
        ProgressManager.shared.updateStreak()
        
        // 🔹 Evaluate progress & trigger review checkpoints
        evaluateProgressAndTriggerReview()
        
        // ✅ Log learning event for adaptive recall
        ProgressManager.shared.updateMemoryState(for: viewModel.currentWord.italian, correct: true)
        
        // 🔸 Check if last word in chapter
        if viewModel.currentIndex == viewModel.words.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // 🔹 Launch final review if not yet mastered
                if !ProgressManager.shared.isChapterMastered(currentChapter) {
                    let finalReview = FinalChapterReviewView(chapter: currentChapter)
                    let host = UIHostingController(rootView: finalReview)
                    
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = scene.windows.first {
                        window.rootViewController = host
                        window.makeKeyAndVisible()
                    }
                } else {
                    // ✅ Show completion summary
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showCompletion = true
                    }
                }
            }
        }
    }



    private func previousWord() {
        viewModel.previousWord()
    }

    // MARK: - Review trigger logic
    private func evaluateProgressAndTriggerReview() {
        // 1️⃣ Compute chapter progress
        currentProgress = Double(viewModel.learnedWords.count) / Double(viewModel.words.count)

        // 2️⃣ Determine current section index (0–9)
        let sectionIndex = progressManager.currentSection(for: currentProgress)

        // 3️⃣ Load checkpoints for this chapter
        var checkpoints = progressManager.reviewCheckpoints(for: currentChapter)
        guard sectionIndex < checkpoints.count else { return }

        // 4️⃣ Trigger review if this checkpoint not yet completed
        if !checkpoints[sectionIndex].completed {
            showReviewSession = true
        }
    }

    private func handleReviewCompletion(passed: Bool, score: Double) {
        let sectionIndex = progressManager.currentSection(for: currentProgress)
        progressManager.updateCheckpoint(
            for: currentChapter,
            section: sectionIndex + 1,
            passed: passed,
            score: score
        )
        showReviewSession = false
    }

    private func nextWord() {
        viewModel.nextWord()
    }

    private func handleNextChapter() {
        showCompletion = false

        if let currentIndex = ChapterList.allCases.firstIndex(of: currentChapter),
           currentIndex < ChapterList.allCases.count - 1 {
            let next = ChapterList.allCases[currentIndex + 1]
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
}
