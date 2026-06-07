//
//  ConceptCardView.swift
//  Patente-Learning
//
//  The L3 "teaching" layer for one Blocco (concept cluster). Shows the
//  English topic, any ministry figures, the curated glossary key terms,
//  an optional concept summary, the true/false split, and a button to
//  start practising the Blocco's real exam questions.
//
//  Philosophy: "distill, don't drill" — give the exam-passer the gist of
//  the concept, then let them test recognition on the actual questions.
//

import SwiftUI

struct ConceptCardView: View {
    let blocco: Blocco

    @State private var startPractice = false

    private var keyTerms: [(it: String, en: String)] {
        // Scan the topic + a few questions for glossary terms.
        let corpus = ([blocco.topic] + blocco.questions.prefix(6).map(\.text))
            .joined(separator: " ")
        return PatenteLexicon.shared.keyTerms(in: corpus, limit: 8)
    }

    /// VoiceOver description for a figure in this concept. Road signs/figures
    /// are otherwise invisible to assistive tech.
    private func figureLabel(index: Int) -> String {
        let count = blocco.figureImageNames.count
        let position = count > 1 ? " \(index + 1) of \(count)" : ""
        return "Figure\(position) for \(blocco.topic_en)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {

                // ── Header ────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text(blocco.chapter)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.accentColor)
                        .textCase(.uppercase)

                    Text(blocco.topic_en)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(blocco.topic)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }

                // ── Figures ───────────────────────────────────────────────
                if !blocco.figureImageNames.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Figures", systemImage: "photo.on.rectangle.angled")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(blocco.figureImageNames.enumerated()), id: \.element) { index, name in
                                    FigureImageView(
                                        imageName: name,
                                        accessibilityLabel: figureLabel(index: index)
                                    )
                                    .frame(width: 150, height: 150)
                                }
                            }
                        }
                    }
                }

                // ── Concept summary (optional) ────────────────────────────
                if let summary = blocco.concept_summary_en, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("The gist", systemImage: "lightbulb.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(summary)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                }

                // ── Key terms ─────────────────────────────────────────────
                if !keyTerms.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Key terms", systemImage: "character.book.closed.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        ChipFlowLayout(spacing: 8) {
                            ForEach(keyTerms, id: \.it) { term in
                                HStack(spacing: 5) {
                                    Text(term.it)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Text(term.en)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.accentColor.opacity(0.1)))
                            }
                        }
                    }
                }

                // ── True/False split ──────────────────────────────────────
                HStack(spacing: 12) {
                    countPill(label: "True", count: blocco.question_count_true, color: .green)
                    countPill(label: "False", count: blocco.question_count_false, color: .red)
                    countPill(label: "Total", count: blocco.questions.count, color: .indigo)
                }

                Spacer(minLength: 8)

                // ── Start practice ────────────────────────────────────────
                Button {
                    startPractice = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Practice these questions")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Concept")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $startPractice) {
            TrueFalsePracticeView(blocco: blocco, onFinish: { startPractice = false })
        }
    }

    @ViewBuilder
    private func countPill(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - ChipFlowLayout

/// A simple wrapping HStack for the key-term chips (iOS 16+ Layout protocol).
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
