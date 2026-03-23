//
//  TappableSentenceView.swift
//  Patente-Learning
//
//  Renders an Italian sentence as individually tappable word tokens.
//  Tapping a word shows its English translation in a pill above the sentence.
//  Tokens made entirely of underscores (______) are rendered as blank slots.
//
//  Layout strategy:
//    Uses GeometryReader + PreferenceKey to measure the container width,
//    then pre-computes word-wrap rows using UIFont text measurement.
//    This avoids the Layout protocol and works reliably in all containers.
//
//  Usage:
//    TappableSentenceView(sentence: example.sentence)          // context card
//    TappableSentenceView(sentence: maskedSentence)            // fill-in-blank
//

import SwiftUI
import UIKit

// MARK: - TappableSentenceView

struct TappableSentenceView: View {

    let sentence: String

    @State private var activeWord:        String? = nil
    @State private var activeTranslation: String? = nil
    @State private var containerWidth:    CGFloat = 320   // sensible fallback

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // ── Translation tooltip ───────────────────────────────────────
            ZStack(alignment: .leading) {
                if let word = activeWord, let translation = activeTranslation {
                    HStack(spacing: 6) {
                        Text(word)
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(translation)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
                            )
                    )
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: activeWord)

            // ── Width probe (invisible, zero-height) ─────────────────────
            Color.clear
                .frame(height: 0)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: SentenceWidthKey.self,
                                value: geo.size.width
                            )
                    }
                )
                .onPreferenceChange(SentenceWidthKey.self) { w in
                    if w > 0 { containerWidth = w }
                }

            // ── Wrapped word rows ─────────────────────────────────────────
            let tokens = tokenize(sentence)
            let rows   = buildRows(tokens: tokens, availableWidth: containerWidth)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 4) {
                        ForEach(rows[rowIndex]) { token in
                            tokenView(token)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Token View

    @ViewBuilder
    private func tokenView(_ token: SentenceToken) -> some View {
        if token.isBlank {
            // Blank slot — styled, non-tappable
            Text("______")
                .font(.body.weight(.bold))
                .foregroundColor(.accentColor)

        } else if let translation = token.translation {
            // Tappable word — has a known translation
            let isActive = activeWord == token.id

            Button {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                    if isActive {
                        activeWord        = nil
                        activeTranslation = nil
                    } else {
                        activeWord        = token.id
                        activeTranslation = translation
                    }
                }
            } label: {
                Text(token.raw)
                    .font(.body.weight(.medium))
                    .foregroundColor(isActive ? .accentColor : .primary)
                    .underline(isActive, color: .accentColor)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        } else {
            // Non-tappable word — no translation found
            Text(token.raw)
                .font(.body)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Tokeniser

    private func tokenize(_ text: String) -> [SentenceToken] {
        text
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, raw in
                let stripped = raw.trimmingCharacters(
                    in: CharacterSet(charactersIn: ".,;:!?\"'()[]–—-«»")
                )
                let isBlank = !stripped.isEmpty && stripped.allSatisfy { $0 == "_" }

                return SentenceToken(
                    index:       index,
                    raw:         raw,
                    isBlank:     isBlank,
                    translation: isBlank ? nil : ItalianLookup.shared.translate(raw)
                )
            }
    }

    // MARK: - Row builder

    /// Groups tokens into lines that fit within `availableWidth` using
    /// UIFont text measurement so no custom Layout protocol is needed.
    private func buildRows(tokens: [SentenceToken], availableWidth: CGFloat) -> [[SentenceToken]] {
        guard !tokens.isEmpty, availableWidth > 0 else {
            return tokens.isEmpty ? [] : [tokens]
        }

        let font     = UIFont.preferredFont(forTextStyle: .body)
        let spacing: CGFloat = 4   // must match HStack spacing above

        var rows:         [[SentenceToken]] = []
        var currentRow:   [SentenceToken]   = []
        var currentWidth: CGFloat           = 0

        for token in tokens {
            let tokenW   = measureWidth(token.raw, font: font)
            let addedW   = currentRow.isEmpty ? tokenW : tokenW + spacing

            if !currentRow.isEmpty, currentWidth + addedW > availableWidth {
                rows.append(currentRow)
                currentRow   = [token]
                currentWidth = tokenW
            } else {
                currentRow.append(token)
                currentWidth += addedW
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }
        return rows
    }

    /// Returns the rendered pixel width of a string at the given UIFont.
    private func measureWidth(_ text: String, font: UIFont) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let rect = (text as NSString).boundingRect(
            with:    CGSize(width: CGFloat.greatestFiniteMagnitude, height: 100),
            options: .usesLineFragmentOrigin,
            attributes: attrs,
            context: nil
        )
        return ceil(rect.width) + 2   // 2 pt safety buffer for anti-aliasing
    }
}

// MARK: - PreferenceKey

private struct SentenceWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - SentenceToken

private struct SentenceToken: Identifiable {
    let index:       Int
    let raw:         String
    let isBlank:     Bool
    let translation: String?

    /// Stable ID: index ensures repeated words don't collide.
    var id: String { "\(index):\(raw)" }
}

// MARK: - Preview

#Preview("Context sentence") {
    TappableSentenceView(
        sentence: "Il conducente deve rispettare il limite di velocità."
    )
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Fill-in-the-blank") {
    TappableSentenceView(
        sentence: "I fari possono ______ gli altri utenti della strada."
    )
    .padding()
    .background(Color(.systemBackground))
}
