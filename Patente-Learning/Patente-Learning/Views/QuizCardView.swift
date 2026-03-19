//
//  QuizCardView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 17/03/26.
//
//  A self-contained multiple-choice challenge card.
//  Shown after the user studies a word card and taps "I Know This".
//  Calls onResult(correct: Bool) when the user has answered.
//
import SwiftUI

struct QuizCardView: View {
    let word: Words          // The word being tested
    let allWords: [Words]    // Full word list — used to generate distractors
    let onResult: (Bool) -> Void

    // ── State ─────────────────────────────────────────────────────────────
    @State private var options: [String] = []
    @State private var selected: String? = nil
    @State private var answered = false
    @State private var shake = false

    var body: some View {
        VStack(spacing: 28) {

            // ── Prompt ────────────────────────────────────────────────────
            VStack(spacing: 8) {
                Text("What does this mean?")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                Text(word.italian)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let type = word.type {
                    Text(type.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }
            }
            .padding(.top, 12)

            // ── Options ───────────────────────────────────────────────────
            VStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    optionButton(option)
                }
            }
            .modifier(ShakeEffect(animatableData: shake ? 1 : 0))
            .padding(.horizontal)

            // ── Feedback + Continue ───────────────────────────────────────
            if answered {
                feedbackRow
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 24)
        .background(Color.appBackground)
        .onAppear { buildOptions() }
        .animation(.easeInOut(duration: 0.2), value: answered)
    }

    // MARK: - Option Button

    @ViewBuilder
    private func optionButton(_ option: String) -> some View {
        Button {
            guard !answered else { return }
            handleSelection(option)
        } label: {
            HStack {
                Text(option)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.leading)
                Spacer()
                if answered {
                    Image(systemName: iconName(for: option))
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(buttonFill(for: option))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(buttonBorder(for: option), lineWidth: 2)
            )
            .foregroundColor(buttonForeground(for: option))
            .scaleEffect(answered && option == word.english ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: answered)
        }
        .disabled(answered)
    }

    // MARK: - Feedback Row

    private var feedbackRow: some View {
        let isCorrect = selected == word.english
        return VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title3)
                Text(isCorrect ? "Corretto!" : "La risposta era: \(word.english)")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(isCorrect ? .green : .red)

            Button {
                onResult(isCorrect)
            } label: {
                Text(isCorrect ? "Continue" : "Got it")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(isCorrect ? Color.green : Color.orange))
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Logic

    private func handleSelection(_ option: String) {
        selected = option
        answered = true

        if option == word.english {
            HapticsManager.success()
        } else {
            HapticsManager.error()
            withAnimation(.default) { shake = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { shake = false }
        }
    }

    private func buildOptions() {
        // 3 distractors from other words + the correct answer
        let distractors = allWords
            .filter { $0.english != word.english }
            .shuffled()
            .prefix(3)
            .map { $0.english }

        options = Array(Set(distractors + [word.english])).shuffled()
    }

    // MARK: - Styling Helpers

    private func buttonFill(for option: String) -> Color {
        guard answered else { return Color.secondary.opacity(0.08) }
        if option == word.english { return Color.green.opacity(0.15) }
        if option == selected { return Color.red.opacity(0.15) }
        return Color.secondary.opacity(0.06)
    }

    private func buttonBorder(for option: String) -> Color {
        guard answered else { return Color.secondary.opacity(0.2) }
        if option == word.english { return Color.green.opacity(0.7) }
        if option == selected { return Color.red.opacity(0.7) }
        return Color.secondary.opacity(0.1)
    }

    private func buttonForeground(for option: String) -> Color {
        guard answered else { return .primary }
        if option == word.english { return .green }
        if option == selected { return .red }
        return .secondary
    }

    private func iconName(for option: String) -> String {
        if option == word.english { return "checkmark.circle.fill" }
        if option == selected { return "xmark.circle.fill" }
        return ""
    }
}

// MARK: - Preview

#Preview {
    QuizCardView(
        word: Words(
            italian: "abbagliare",
            english: "dazzle",
            type: "verb",
            examples: [
                Example(sentence: "I fari possono abbagliare gli altri utenti.", label: "vero")
            ]
        ),
        allWords: [
            Words(italian: "svolta", english: "turn"),
            Words(italian: "corsia", english: "lane"),
            Words(italian: "senso unico", english: "one way"),
            Words(italian: "incrocio", english: "junction"),
            Words(italian: "semaforo", english: "traffic light")
        ],
        onResult: { correct in
            print("Answer was \(correct ? "correct" : "wrong")")
        }
    )
}
