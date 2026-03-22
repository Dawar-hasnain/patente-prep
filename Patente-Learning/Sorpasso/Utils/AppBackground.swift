//
//  AppBackground.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//

import SwiftUI

extension Color {
    static var appBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.systemGray6 // darker grey for dark mode
            : UIColor.systemGray5 // lighter grey for light mode
        })
    }
}
