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
}
