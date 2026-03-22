//
//  FillInTheBlankCardView.swift
//  Patente-Learning
//
//  Gated exercise — only shown when a word has correctCount ≥ 3.
//  Displays a masked Italian example sentence and four Italian word choices.
//  If the word has no example sentence, ExerciseEngine falls back to WordBank.
//

import SwiftUI

struct FillInTheBlankCardView: View {
    let word: Words
    let maskedSentence: String     // e.g. "La ______ è vietata."
    let choices: [String]          // 4 Italian options (correct + 3 distractors)
    let onResult: (Bool) -> Void

    // MARK: State
    @State private var selected: String? = nil
    @State private var answered  = false
    @State private var shake     = false

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {

            // ── Instruction + Sentence ────────────────────────────────────
            VStack(spacing: 20) {
                Text("Fill in the blank")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 32)

                // English translation hint — gives context without giving away the answer
                Text("(\(word.english))")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .italic()

                // Masked sentence card
                Text(maskedSentence)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 22)
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
            }

            Spacer(minLength: 32)

            // ── Answer Choices ────────────────────────────────────────────
            VStack(spacing: 12) {
                ForEach(choices, id: \.self) { choice in
                    choiceButton(choice)
                }
            }
            .modifier(ShakeEffect(animatableData: shake ? 1 : 0))
            .padding(.horizontal)

            Spacer(minLength: 24)

            // ── Feedback Banner ───────────────────────────────────────────
            if answered {
                feedbackBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: answered)
    }

    // MARK: - Choice Button

    @ViewBuilder
    private func choiceButton(_ choice: String) -> some View {
        let isCorrect = choice == word.italian
        let isSelected = choice == selected

        Button {
            guard !answered else { return }
            handleSelection(choice)
        } label: {
            HStack {
                Text(choice)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.leading)
                Spacer()
                if answered {
                    Image(systemName: isCorrect ? "checkmark.circle.fill"
                          : (isSelected ? "xmark.circle.fill" : ""))
                        .font(.body.weight(.semibold))
                        .opacity(isCorrect || isSelected ? 1 : 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(fillColor(choice))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(borderColor(choice), lineWidth: 2)
            )
            .foregroundColor(textColor(choice))
            .scaleEffect(answered && isCorrect ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: answered)
        }
        .disabled(answered)
    }

    // MARK: - Feedback Banner

    private var feedbackBanner: some View {
        let isCorrect = selected == word.italian
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
                            Text("The missing word: \(word.italian)")
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

    // MARK: - Logic

    private func handleSelection(_ choice: String) {
        selected = choice
        answered = true
        if choice == word.italian {
            HapticsManager.success()
        } else {
            HapticsManager.error()
            withAnimation(.default) { shake = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
        }
    }

    // MARK: - Styling

    private func fillColor(_ choice: String) -> Color {
        guard answered else { return Color.secondary.opacity(0.07) }
        if choice == word.italian { return Color.green.opacity(0.12) }
        if choice == selected     { return Color.red.opacity(0.12) }
        return Color.secondary.opacity(0.05)
    }

    private func borderColor(_ choice: String) -> Color {
        guard answered else { return Color.secondary.opacity(0.18) }
        if choice == word.italian { return Color.green.opacity(0.7) }
        if choice == selected     { return Color.red.opacity(0.7) }
        return Color.secondary.opacity(0.08)
    }

    private func textColor(_ choice: String) -> Color {
        guard answered else { return .primary }
        if choice == word.italian { return .green }
        if choice == selected     { return .red }
        return .secondary
    }
}

// MARK: - Preview

#Preview {
    FillInTheBlankCardView(
        word: Words(
            italian: "abbagliare",
            english: "to dazzle",
            examples: [Example(sentence: "I fari possono abbagliare gli altri utenti.", label: "vero")]
        ),
        maskedSentence: "I fari possono ______ gli altri utenti.",
        choices: ["abbagliare", "svoltare", "sorpassare", "frenare"],
        onResult: { print("Correct: \($0)") }
    )
}
