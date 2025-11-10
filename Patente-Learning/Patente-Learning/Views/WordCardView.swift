//
//  WordCardView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//

import SwiftUI

struct WordCardView: View {
    let word: Words
    @Binding var flipped: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .rotation3DEffect(.degrees(flipped ? 180 : 0),
                                  axis: (x: 0, y: 1, z: 0))
                .animation(.easeInOut(duration: 0.4), value: flipped)
                .onTapGesture { flipped.toggle() }
                .overlay(
                    VStack {
                        Spacer()
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(.bottom, 10)
                    }
                )


            VStack(spacing: 16) {
                if flipped {
                    // Back Side — show both Italian + English
                    VStack(spacing: 10) {
                        Text(word.italian)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.top, 12)

                        Divider()
                            .frame(width: 60)
                            .overlay(Color.primary.opacity(0.2))

                        Text(word.english)
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                    }
                    .padding(.bottom, 12)
                } else {
                    // Front Side — Italian only
                    Text(word.italian)
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding()
                }
            }
            .padding()
        }
        .glassCard()
        .padding()
    }
}
