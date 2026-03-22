//
//  TapThePairsView.swift
//  Patente-Learning
//
//  Duolingo-style matching exercise.
//  The user taps one Italian tile, then one English tile.
//  A correct match makes both tiles disappear with a spring pop.
//  All pairs matched → calls onComplete().
//

import SwiftUI

struct TapThePairsView: View {
    let pairs: [WordPair]
    let onComplete: (Bool) -> Void   // Bool: were all matched (always true here)

    // MARK: - State
    @State private var selectedItalian: String? = nil
    @State private var selectedEnglish: String? = nil
    @State private var matched: Set<String> = []          // matched Italian words
    @State private var wrongPair: (String, String)? = nil // flashes red briefly
    @State private var completedScale: CGFloat = 0

    // Shuffled once so columns don't mirror each other
    private let italianOrder: [WordPair]
    private let englishOrder: [WordPair]

    init(pairs: [WordPair], onComplete: @escaping (Bool) -> Void) {
        self.pairs = pairs
        self.onComplete = onComplete
        self.italianOrder = pairs.shuffled()
        self.englishOrder = pairs.shuffled()
    }

    var body: some View {
        VStack(spacing: 28) {

            // ── Instruction ───────────────────────────────────────────────
            Text("Tap the matching pairs")
                .font(.headline.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.top, 8)

            // ── Two columns ───────────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {

                // Left: Italian
                VStack(spacing: 10) {
                    ForEach(italianOrder) { pair in
                        pairTile(
                            text: pair.italian,
                            isSelected: selectedItalian == pair.italian,
                            isMatched: matched.contains(pair.italian),
                            isWrong: wrongPair?.0 == pair.italian
                        )
                        .onTapGesture {
                            guard !matched.contains(pair.italian) else { return }
                            HapticsManager.lightTap()
                            selectedItalian = pair.italian
                            checkForMatch()
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // Right: English
                VStack(spacing: 10) {
                    ForEach(englishOrder) { pair in
                        pairTile(
                            text: pair.english,
                            isSelected: selectedEnglish == pair.english,
                            isMatched: matched.contains(pair.italian),
                            isWrong: wrongPair?.1 == pair.english
                        )
                        .onTapGesture {
                            // Find the Italian key for this English tile
                            guard let owner = pairs.first(where: { $0.english == pair.english }),
                                  !matched.contains(owner.italian) else { return }
                            HapticsManager.lightTap()
                            selectedEnglish = pair.english
                            checkForMatch()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    // MARK: - Tile View

    @ViewBuilder
    private func pairTile(
        text: String,
        isSelected: Bool,
        isMatched: Bool,
        isWrong: Bool
    ) -> some View {
        let bgColor: Color = {
            if isMatched  { return Color.green.opacity(0.15) }
            if isWrong    { return Color.red.opacity(0.15) }
            if isSelected { return Color.accentColor.opacity(0.15) }
            return Color.secondary.opacity(0.08)
        }()

        let borderColor: Color = {
            if isMatched  { return Color.green.opacity(0.6) }
            if isWrong    { return Color.red.opacity(0.6) }
            if isSelected { return Color.accentColor }
            return Color.secondary.opacity(0.2)
        }()

        Text(text)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundColor(isMatched ? .green : (isWrong ? .red : .primary))
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(bgColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .opacity(isMatched ? 0.45 : 1.0)
            .scaleEffect(isMatched ? 0.95 : (isSelected ? 1.03 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isMatched)
            .animation(.default, value: isWrong)
    }

    // MARK: - Match Logic

    private func checkForMatch() {
        guard let italian = selectedItalian, let english = selectedEnglish else { return }

        // Find the pair that owns this Italian word
        guard let pair = pairs.first(where: { $0.italian == italian }) else { return }

        if pair.english == english {
            // ── Correct ───────────────────────────────────────────────────
            HapticsManager.success()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                matched.insert(italian)
            }
            selectedItalian = nil
            selectedEnglish = nil

            // All matched?
            if matched.count == pairs.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete(true)
                }
            }
        } else {
            // ── Wrong ─────────────────────────────────────────────────────
            HapticsManager.error()
            wrongPair = (italian, english)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                wrongPair = nil
                selectedItalian = nil
                selectedEnglish = nil
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TapThePairsView(
        pairs: [
            WordPair(italian: "corsia",    english: "lane"),
            WordPair(italian: "freno",     english: "brake"),
            WordPair(italian: "incrocio",  english: "junction"),
            WordPair(italian: "semaforo",  english: "traffic light"),
        ],
        onComplete: { _ in print("Done!") }
    )
}
