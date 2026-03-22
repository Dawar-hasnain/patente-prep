//
//  ShakeEffect.swift
//  Patente-Learning
//
//  Reusable GeometryEffect that applies a horizontal shake animation.
//  Used by exercise cards in LessonSessionView, HeartsView, and RecallModeView on wrong answers.
//

import SwiftUI

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
