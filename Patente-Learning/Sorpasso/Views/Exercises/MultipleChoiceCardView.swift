//
//  MultipleChoiceCardView.swift
//  Patente-Learning
//
//  Handles two exercise modes from a single view:
//
//  • .whatDoesItMean  — shows Italian word, user picks English meaning
//  • .howDoYouSay     — shows English word, user picks Italian translation
//
//  After the user taps an answer:
//  • Correct → green highlight + "Corretto!" feedback banner
//  • Wrong   → red highlight on chosen, green reveals correct + shake
//  "Continue" button appears and calls onResult(correct:).
//

import SwiftUI

// MARK: - Mode

enum MultipleChoiceMode {
    case whatDoesItMean   // IT → EN
    case howDoYouSay      // EN → IT
}

// MARK: - View

struct MultipleChoiceCardView: View {
    let mode: MultipleChoiceMode
    let word: Words
    let choices: [String]              // already shuffled by SessionBuilder
    let onResult: (Bool) -> Void

    // MARK: State
    @State private var selected: String? = nil
    @State private var answered  = false
    @State private var shake     = false

    // MARK: Derived
    private var prompt: String {
        switch mode {
        case .whatDoesItMean: return word.italian
        case .howDoYouSay:    return word.english
        }
    }
    private var instruction: String {
        switch mode {
        case .whatDoesItMean: return "What does this mean?"
        case .howDoYouSay:    return "How do you say this in Italian?"
        }
    }
    private var correctAnswer: String {
        switch mode {
        case .whatDoesItMean: return word.english
        case .howDoYouSay:    return word.italian
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {

            // ── Instruction + Prompt ──────────────────────────────────────
            VStack(spacing: 12) {
                Text(instruction)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                Text(prompt)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Speaker button — always speaks the Italian word
                Button {
                    SpeechManager.shared.speak(word.italian)
                    HapticsManager.lightTap()
                } label: {
                    Label("Pronounce", systemImage: "speaker.wave.2.fill")
                        .labelStyle(.iconOnly)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.accentColor)
                        .padding(10)
                        .background(Circle().fill(Color.accentColor.opacity(0.1)))
                }

                // Word type badge (only for IT→EN)
                if mode == .whatDoesItMean, let type = word.type {
                    Text(type.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.1)))
                }
            }
            .padding(.top, 32)
            .padding(.bottom, 32)

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
        let isCorrect = choice == correctAnswer
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

    // MARK: - Logic

    private func handleSelection(_ choice: String) {
        selected = choice
        answered = true
        if choice == correctAnswer {
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
        if choice == correctAnswer { return Color.green.opacity(0.12) }
        if choice == selected      { return Color.red.opacity(0.12) }
        return Color.secondary.opacity(0.05)
    }

    private func borderColor(_ choice: String) -> Color {
        guard answered else { return Color.secondary.opacity(0.18) }
        if choice == correctAnswer { return Color.green.opacity(0.7) }
        if choice == selected      { return Color.red.opacity(0.7) }
        return Color.secondary.opacity(0.08)
    }

    private func textColor(_ choice: String) -> Color {
        guard answered else { return .primary }
        if choice == correctAnswer { return .green }
        if choice == selected      { return .red }
        return .secondary
    }
}

// MARK: - Preview

#Preview("What Does It Mean") {
    MultipleChoiceCardView(
        mode: .whatDoesItMean,
        word: Words(italian: "corsia", english: "lane", type: "noun"),
        choices: ["highway", "lane", "bridge", "parking"],
        onResult: { print("Correct: \($0)") }
    )
}

#Preview("How Do You Say") {
    MultipleChoiceCardView(
        mode: .howDoYouSay,
        word: Words(italian: "sorpasso", english: "overtake", type: "noun"),
        choices: ["incrocio", "semaforo", "sorpasso", "corsia"],
        onResult: { print("Correct: \($0)") }
    )
}
