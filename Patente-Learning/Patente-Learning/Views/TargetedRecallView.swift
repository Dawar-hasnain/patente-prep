//
//  TargetedRecallView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 11/11/25.
//

import SwiftUI

struct TargetedRecallView: View {
    @Environment(\.dismiss) private var dismiss

    @State var weakStates: [WordMemoryState]
    @State private var index = 0
    @State private var score = 0
    @State private var showQuiz = false

    // All words from every chapter — used as the distractor pool for QuizCardView
    private let allWords: [Words] = ChapterList.allCases.flatMap {
        loadChapter($0.filename).words
    }

    // The current weak word as a full Words object (needed by QuizCardView)
    private var currentWord: Words? {
        guard index < weakStates.count else { return nil }
        let italian = weakStates[index].word
        return allWords.first { $0.italian == italian }
            ?? Words(italian: italian,
                     english: ProgressManager.shared.translation(for: italian) ?? "—")
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 20) {

                // ── Top Bar ───────────────────────────────────────────────
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Weak Words")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Text("\(min(index + 1, weakStates.count))/\(weakStates.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // ── Progress Bar ──────────────────────────────────────────
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * barProgress)
                            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: index)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal)

                Spacer()

                if index < weakStates.count {

                    // ── Word Card ─────────────────────────────────────────
                    VStack(spacing: 16) {
                        Text("Do you remember this word?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(weakStates[index].word)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        // Confidence badge
                        confidenceBadge(for: weakStates[index].confidence)

                        Button {
                            HapticsManager.lightTap()
                            showQuiz = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "brain.head.profile")
                                Text("Test Myself")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                            .foregroundColor(.white)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                    }

                } else {

                    // ── Result ────────────────────────────────────────────
                    VStack(spacing: 16) {
                        Image(systemName: score >= weakStates.count / 2 ? "checkmark.seal.fill" : "arrow.triangle.2.circlepath")
                            .font(.system(size: 64))
                            .foregroundColor(score >= weakStates.count / 2 ? .green : .orange)

                        Text("Session Complete")
                            .font(.title.bold())

                        Text("\(score) of \(weakStates.count) correct")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        Button("Done") { dismiss() }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.green))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .animation(.easeInOut, value: index)
        // ── Quiz Sheet ────────────────────────────────────────────────────
        .sheet(isPresented: $showQuiz) {
            if let word = currentWord {
                QuizCardView(
                    word: word,
                    allWords: allWords,
                    onResult: { correct in
                        showQuiz = false
                        ProgressManager.shared.updateMemoryState(
                            for: weakStates[index].word,
                            correct: correct
                        )
                        if correct {
                            HapticsManager.success()
                            score += 1
                        } else {
                            HapticsManager.error()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { index += 1 }
                        }
                    }
                )
                .presentationDetents([.fraction(0.6)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
        }
    }

    // MARK: - Helpers

    private var barProgress: CGFloat {
        guard !weakStates.isEmpty else { return 0 }
        return CGFloat(index) / CGFloat(weakStates.count)
    }

    @ViewBuilder
    private func confidenceBadge(for confidence: Double) -> some View {
        let (label, color): (String, Color) = {
            switch confidence {
            case 0..<0.3: return ("Very Weak", .red)
            case 0.3..<0.6: return ("Weak", .orange)
            default: return ("Needs Review", .yellow)
            }
        }()

        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(color))
    }
}

// MARK: - Preview

#Preview {
    TargetedRecallView(weakStates: [
        WordMemoryState(
            word: "abbagliare",
            lastReviewed: Date(),
            confidence: 0.2,
            correctCount: 1,
            incorrectCount: 4
        ),
        WordMemoryState(
            word: "corsia",
            lastReviewed: Date(),
            confidence: 0.3,
            correctCount: 2,
            incorrectCount: 3
        )
    ])
}
