//
//  TrueFalsePracticeView.swift
//  Patente-Learning
//
//  Practises one Blocco's REAL ministry true/false questions, one at a time.
//  The Italian sentence is tappable (per-word glosses via TappableSentenceView);
//  a "Show English" toggle reveals the full machine-translated gloss. The user
//  answers VERO / FALSO, gets immediate feedback against the ground truth, then
//  advances. Ends with a score summary.
//

import SwiftUI

struct TrueFalsePracticeView: View {
    let title: String
    let sourceQuestions: [Question]
    let onFinish: () -> Void

    /// Convenience: practise a Blocco's questions.
    init(blocco: Blocco, onFinish: @escaping () -> Void) {
        self.title = blocco.topic_en
        self.sourceQuestions = blocco.questions
        self.onFinish = onFinish
    }

    /// General: practise an arbitrary set of questions (e.g. weak-question review).
    init(title: String, questions: [Question], onFinish: @escaping () -> Void) {
        self.title = title
        self.sourceQuestions = questions
        self.onFinish = onFinish
    }

    @State private var questions: [Question] = []
    @State private var index = 0
    @State private var answered = false
    @State private var lastCorrect = false
    @State private var showEnglish = false
    @State private var correctCount = 0
    @State private var finished = false

    private var current: Question? {
        guard index < questions.count else { return nil }
        return questions[index]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if finished {
                    resultView
                } else if let q = current {
                    questionView(q)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { onFinish() }
                }
                ToolbarItem(placement: .principal) {
                    if !finished, !questions.isEmpty {
                        Text("\(index + 1) / \(questions.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            if questions.isEmpty {
                questions = sourceQuestions.shuffled()
            }
        }
    }

    // MARK: - Question

    @ViewBuilder
    private func questionView(_ q: Question) -> some View {
        VStack(spacing: 20) {

            // Progress bar
            ProgressView(value: Double(index), total: Double(max(questions.count, 1)))
                .tint(.accentColor)
                .padding(.horizontal)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {

                    Text("True or false?")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    // Italian (tappable) sentence
                    TappableSentenceView(sentence: q.text)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(14)

                    // English toggle
                    Button {
                        withAnimation { showEnglish.toggle() }
                    } label: {
                        Label(showEnglish ? "Hide English" : "Show English",
                              systemImage: "character.bubble")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)

                    if showEnglish {
                        Text(q.text_en)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentColor.opacity(0.08))
                            .cornerRadius(12)
                            .transition(.opacity)
                    }

                    // Feedback
                    if answered {
                        feedbackBanner(q)
                    }
                }
                .padding()
            }

            Spacer(minLength: 0)

            // Answer / Continue controls
            if answered {
                Button(action: advance) {
                    Text(index + 1 < questions.count ? "Continue" : "See results")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 24)
            } else {
                HStack(spacing: 14) {
                    answerButton(title: "VERO", subtitle: "True", color: .green, value: true, q: q)
                    answerButton(title: "FALSO", subtitle: "False", color: .red, value: false, q: q)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func answerButton(title: String, subtitle: String, color: Color, value: Bool, q: Question) -> some View {
        Button {
            answer(value, for: q)
        } label: {
            VStack(spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption2).opacity(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(color))
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func feedbackBanner(_ q: Question) -> some View {
        HStack(spacing: 10) {
            Image(systemName: lastCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(lastCorrect ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(lastCorrect ? "Correct" : "Not quite")
                    .font(.subheadline.weight(.bold))
                Text("Answer: \(q.answer ? "VERO (True)" : "FALSO (False)")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((lastCorrect ? Color.green : Color.red).opacity(0.12))
        .cornerRadius(12)
        .transition(.opacity)
    }

    // MARK: - Result

    private var resultView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: scoreIcon)
                .font(.system(size: 64))
                .foregroundColor(scoreColor)
            Text("\(correctCount) / \(questions.count)")
                .font(.largeTitle.weight(.bold))
            Text("correct")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(scoreMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button(action: onFinish) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private var scoreRatio: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(correctCount) / Double(questions.count)
    }
    private var scoreIcon: String { scoreRatio >= 0.85 ? "star.circle.fill" : "checkmark.seal.fill" }
    private var scoreColor: Color { scoreRatio >= 0.85 ? .yellow : (scoreRatio >= 0.6 ? .green : .orange) }
    private var scoreMessage: String {
        switch scoreRatio {
        case 0.85...: return "Excellent — you clearly recognise this concept."
        case 0.6..<0.85: return "Good. Re-read the ones you missed and try again."
        default: return "Worth another pass — review the concept card and retry."
        }
    }

    // MARK: - Logic

    private func answer(_ value: Bool, for q: Question) {
        lastCorrect = (value == q.answer)
        if lastCorrect { correctCount += 1 }
        // HIG: map feedback to the matching semantic haptic.
        lastCorrect ? HapticsManager.success() : HapticsManager.error()
        ExamProgressManager.shared.record(q, correct: lastCorrect)
        withAnimation { answered = true }
    }

    private func advance() {
        if index + 1 < questions.count {
            index += 1
            answered = false
            showEnglish = false
        } else {
            withAnimation { finished = true }
        }
    }
}
