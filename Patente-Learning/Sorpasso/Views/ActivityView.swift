//
//  ActivityView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//

import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
