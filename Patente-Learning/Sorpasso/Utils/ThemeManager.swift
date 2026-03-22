//
//  ThemeManager.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 11/11/25.
//

import Foundation
import SwiftUI

enum ThemeColor: String, CaseIterable, Identifiable {
    case Blue, Green, Orange, Purple, Red
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .Blue: return .blue
        case .Green: return .green
        case .Orange: return .orange
        case .Purple: return .purple
        case .Red: return .red
        }
    }
}

struct ThemeManager {
    @AppStorage("accentColor") private var accentColorName: String = ThemeColor.Blue.rawValue
    
    var currentColor: Color {
        ThemeColor(rawValue: accentColorName)?.color ?? .blue
    }
    
    func setTheme(_ theme: ThemeColor) {
        UserDefaults.standard.set(theme.rawValue, forKey: "accentColor")
        HapticsManager.lightTap()
    }
}
