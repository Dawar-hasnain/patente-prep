//
//  ViewExtensions.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 11/11/25.
//

import Foundation
import SwiftUI

extension View {
    /// Soft “glass” background effect for cards and sections
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

extension Color {
    static let appBackgroundColor = Color("AppBackground") // from Assets
    static let cardBackground = Color("CardBackground")
}
