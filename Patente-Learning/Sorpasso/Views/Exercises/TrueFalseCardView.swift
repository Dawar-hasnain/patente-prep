//
//  TrueFalseCardView.swift
//  Patente-Learning
//
//  Simplified True / False exercise.
//  Shows: "[italian]  =  [displayed english]" — is this correct?
//
//  The displayed translation is either the real English meaning (answer: true)
//  or a distractor from another word (answer: false).
//  This is determined at question-generation time by ExerciseEngine.
//

import SwiftUI

struct TrueFalseCardView: View {
    let word: Words
    let displayedTranslation: String   // may be correct OR an impostor
    let isCorrect: Bool                // ground truth
    let onResult: (Bool) -> Void

    // MARK: State
    @State private var answered = false
    @State private var selectedTrue: Bool? = nil
    @State private var shake = false

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {

            // ── Instruction ───────────────────────────────────────────────
            VStack(spacing: 20) {
                Text("True or False?")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 32)

                // Word card
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Text(word.italian)
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundColor(.primary)

                        Button {
                            SpeechManager.shared.speak(word.italian)
                            HapticsManager.lightTap()
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.callout.weight(.semibold))
                                .foregroundColor(.accentColor)
                                .padding(8)
                                .background(Circle().fill(Color.accentColor.opacity(0.1)))
                        }
                    }

                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                        Text("means")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 40)

                    Text(displayedTranslation)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 28)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.secondary.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
                .modifier(ShakeEffect(animatableData: shake ? 1 : 0))
            }

            Spacer(minLength: 32)

            // ── TRUE / FALSE Buttons ──────────────────────────────────────
            if !answered {
                HStack(spacing: 14) {
                    tfButton(label: "TRUE",  systemImage: "checkmark", userSaidTrue: true,  color: .green)
                    tfButton(label: "FALSE", systemImage: "xmark",     userSaidTrue: false, color: .red)
                }
                .padding(.horizontal)
                .padding(.bottom, 48)
            }

            // ── Feedback Banner ───────────────────────────────────────────
            if answered {
                feedbackBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: answered)
    }

    // MARK: - TRUE / FALSE Button

    @ViewBuilder
    private func tfButton(
        label: String,
        systemImage: String,
        userSaidTrue: Bool,
        color: Color
    ) -> some View {
        Button {
            guard !answered else { return }
            handleAnswer(userSaidTrue: userSaidTrue)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.bold))
                Text(label)
                    .font(.headline.weight(.bold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(color.opacity(0.4), lineWidth: 2)
            )
        }
        .disabled(answered)
    }

    // MARK: - Feedback Banner

    private var feedbackBanner: some View {
        let userWasRight = selectedTrue == isCorrect
        let correctLabel = isCorrect ? "TRUE" : "FALSE"

        return VStack(spacing: 0) {
            Divider()
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: userWasRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(userWasRight ? "Corretto!" : "Incorrect")
                            .font(.headline.weight(.bold))
                        if !userWasRight {
                            Text(isCorrect
                                 ? "\"\(word.italian)\" really does mean \"\(displayedTranslation)\""
                                 : "The correct translation is \"\(word.english)\"")
                                .font(.subheadline)
                        }
                    }
                    Spacer()
                    Text(correctLabel)
                        .font(.caption.weight(.bold))
                        .foregroundColor(isCorrect ? .green : .red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill((isCorrect ? Color.green : Color.red).opacity(0.12))
                        )
                }
                .foregroundColor(userWasRight ? .green : .red)

                Button {
                    onResult(userWasRight)
                } label: {
                    Text(userWasRight ? "Continue" : "Got it")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(userWasRight ? Color.green : Color.orange)
                        )
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .background(
                (userWasRight ? Color.green : Color.red)
                    .opacity(0.06)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    // MARK: - Logic

    private func handleAnswer(userSaidTrue: Bool) {
        selectedTrue = userSaidTrue
        answered = true
        let correct = userSaidTrue == isCorrect
        if correct {
            HapticsManager.success()
        } else {
            HapticsManager.error()
            withAnimation(.default) { shake = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
        }
    }
}

// MARK: - Preview

#Preview("Correct translation shown") {
    TrueFalseCardView(
        word: Words(italian: "corsia", english: "lane"),
        displayedTranslation: "lane",
        isCorrect: true,
        onResult: { print("Correct: \($0)") }
    )
}

#Preview("Wrong translation shown") {
    TrueFalseCardView(
        word: Words(italian: "corsia", english: "lane"),
        displayedTranslation: "bridge",
        isCorrect: false,
        onResult: { print("Correct: \($0)") }
    )
}
