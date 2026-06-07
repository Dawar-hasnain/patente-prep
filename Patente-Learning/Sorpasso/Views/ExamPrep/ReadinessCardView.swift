//
//  ReadinessCardView.swift
//  Patente-Learning
//
//  Shows the learner's estimated probability of passing the real exam,
//  computed by ReadinessEngine from per-question accuracy + bank coverage.
//  Recomputes whenever ExamProgressManager changes.
//

import SwiftUI

struct ReadinessCardView: View {
    @ObservedObject private var progress = ExamProgressManager.shared

    private var report: ReadinessReport { ReadinessEngine.evaluate() }

    var body: some View {
        let r = report
        let pct = Int((r.probabilityOfPassing * 100).rounded())

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: CGFloat(r.probabilityOfPassing))
                        .stroke(bandColor(r), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(pct)%")
                        .font(.headline.weight(.bold).monospacedDigit())
                }
                .frame(width: 64, height: 64)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: r.probabilityOfPassing)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Exam readiness")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(r.band)
                        .font(.title3.weight(.bold))
                        .foregroundColor(bandColor(r))
                    Text("Estimated chance of passing a 30-question mock exam.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            HStack(spacing: 16) {
                metric(value: "\(Int((r.coverage * 100).rounded()))%",
                       label: "Bank covered")
                metric(value: "\(r.attemptedQuestions)/\(r.totalQuestions)",
                       label: "Questions seen")
                metric(value: "\(Int((r.seenConfidence * 100).rounded()))%",
                       label: "Mastery")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(bandColor(r).opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func bandColor(_ r: ReadinessReport) -> Color {
        switch r.probabilityOfPassing {
        case 0.85...:    return .green
        case 0.6..<0.85: return .blue
        case 0.35..<0.6: return .orange
        default:         return .red
        }
    }
}
