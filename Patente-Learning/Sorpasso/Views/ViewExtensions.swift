//
//  ViewExtensions.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 11/11/25.
//

import Foundation
import SwiftUI

// MARK: - View Modifiers

extension View {
    /// Soft "glass" background effect for cards and sections
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
    }

    /// Rounded card with consistent padding and subtle shadow
    func appCardStyle() -> some View {
        self
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    /// Liquid glass blur and depth (Apple Music / Fitness look)
    func liquidGlassBackground(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    /// Gentle fade+scale transition for modal or state changes
    func smoothTransition(active: Bool) -> some View {
        self
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.4), value: active)
    }
}

// MARK: - Color

extension Color {
    static let appBackgroundColor = Color("AppBackground")
    static let cardBackground     = Color("CardBackground")

    /// Initialise a Color from a hex string e.g. "FF9F0A" or "#FF9F0A"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Comparable

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Array

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
