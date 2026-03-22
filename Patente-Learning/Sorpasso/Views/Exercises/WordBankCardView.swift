//
//  WordBankCardView.swift
//  Patente-Learning
//
//  "Tap to Translate" exercise — Duolingo word-bank style.
//
//  Shows an Italian word and a shuffled bank of English tiles.
//  The user taps the correct English tile to confirm their answer.
//  Tapping a tile in the answer area removes it back to the bank.
//
//  For Phase 1 this works at the word level (no full sentences needed).
//

import SwiftUI

struct WordBankCardView: View {
    let word: Words
    let bank: [String]           // correct english + distractors, pre-shuffled
    let onResult: (Bool) -> Void

    // MARK: State
    @State private var selected: String? = nil     // the tile the user tapped
    @State private var answered  = false
    @State private var shake     = false

    private var correctAnswer: String { word.english }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {

            // ── Instruction + Word ────────────────────────────────────────
            VStack(spacing: 16) {
                Text("Translate into English")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 32)

                // Italian word display card
                Text(word.italian)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.secondary.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)

                if let type = word.type {
                    Text(type.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.1)))
                }
            }

            Spacer(minLength: 28)

            // ── Answer Slot ───────────────────────────────────────────────
            answerSlot
                .padding(.horizontal)

            // ── Divider ───────────────────────────────────────────────────
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 1)
                .padding(.vertical, 20)
                .padding(.horizontal)

            // ── Word Bank ─────────────────────────────────────────────────
            wordBankGrid
                .padding(.horizontal)
                .modifier(ShakeEffect(animatableData: shake ? 1 : 0))

            Spacer(minLength: 16)

            // ── Check Button (locks in the answer) ────────────────────────
            checkButton
                .padding(.horizontal)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)

            Spacer(minLength: 8)

            // ── Feedback Banner ───────────────────────────────────────────
            if answered {
                feedbackBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: answered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }

    // MARK: - Answer Slot

    private var answerSlot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            selected != nil ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: 2, dash: selected == nil ? [6, 4] : [])
                        )
                )
                .frame(height: 52)

            if let s = selected {
                // Show tile in the slot; tapping it returns it to the bank
                Text(s)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(answered
                                  ? (s == correctAnswer ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                  : Color.accentColor.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                answered
                                ? (s == correctAnswer ? Color.green.opacity(0.6) : Color.red.opacity(0.6))
                                : Color.accentColor.opacity(0.4),
                                lineWidth: 1.5
                            )
                    )
                    .onTapGesture {
                        guard !answered else { return }
                        HapticsManager.lightTap()
                        selected = nil
                    }
            } else {
                Text("Tap a word below")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
    }

    // MARK: - Word Bank Grid

    private var wordBankGrid: some View {
        // Wrap tiles like Duolingo — FlowLayout if available, else simple lazy grid
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 90), spacing: 10)],
            spacing: 10
        ) {
            ForEach(bank, id: \.self) { tile in
                let isChosen = selected == tile
                Button {
                    guard !answered, !isChosen else { return }
                    HapticsManager.lightTap()
                    selected = tile
                } label: {
                    Text(tile)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(minWidth: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isChosen
                                      ? Color.secondary.opacity(0.05)
                                      : Color.secondary.opacity(0.09))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    isChosen ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.25),
                                    lineWidth: 1.5
                                )
                        )
                        .foregroundColor(isChosen ? Color.secondary.opacity(0.3) : .primary)
                }
                .disabled(answered || isChosen)
            }
        }
    }

    // MARK: - Feedback Banner

    private var feedbackBanner: some View {
        let isCorrect = selected == correctAnswer
        return VStack(spacing: 0) {
            Divider()
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isCorrect ? "Corretto!" : "Incorrect")
                            .font(.headline.weight(.bold))
                        if !isCorrect {
                            Text("Correct answer: \(correctAnswer)")
                                .font(.subheadline)
                        }
                    }
                    Spacer()
                }
                .foregroundColor(isCorrect ? .green : .red)

                Button {
                    onResult(isCorrect)
                } label: {
                    Text(isCorrect ? "Continue" : "Got it")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isCorrect ? Color.green : Color.orange)
                        )
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .background(
                (isCorrect ? Color.green : Color.red)
                    .opacity(0.06)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    // MARK: - Check Button (shown when a tile is selected but not yet confirmed)
    // Tapping "Check" locks in the answer. This mirrors Duolingo's UX.

    @ViewBuilder
    private var checkButton: some View {
        if selected != nil && !answered {
            Button {
                commitAnswer()
            } label: {
                Text("Check")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Logic

    private func commitAnswer() {
        guard let s = selected else { return }
        answered = true
        if s == correctAnswer {
            HapticsManager.success()
        } else {
            HapticsManager.error()
            withAnimation(.default) { shake = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
        }
    }
}

// MARK: - Preview

#Preview {
    WordBankCardView(
        word: Words(italian: "sorpasso", english: "overtake", type: "noun"),
        bank: ["overtake", "speed", "parking", "lane", "brake"],
        onResult: { print("Correct: \($0)") }
    )
}
