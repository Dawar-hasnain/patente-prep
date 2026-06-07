//
//  FigureImageView.swift
//  Patente-Learning
//
//  Loads a ministry figure PNG (e.g. "fig_0550") from the bundle.
//  The figures are loose PNG resources under Resources/Figures/ (bundled via
//  the Xcode 16 synchronized folder), NOT asset-catalog images — so SwiftUI's
//  Image(name:) won't find them. We resolve the bundle URL and load via UIImage.
//

import SwiftUI
import UIKit

struct FigureImageView: View {
    let imageName: String        // e.g. "fig_0550"
    /// VoiceOver description of the figure (e.g. the Blocco's topic). When nil
    /// the image is treated as decorative and hidden from assistive tech.
    var accessibilityLabel: String? = nil

    var body: some View {
        if let uiImage = Self.loadImage(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .background(Color.white)
                .cornerRadius(10)
                .accessibilityElement()
                .accessibilityLabel(accessibilityLabel ?? "")
                .accessibilityHidden(accessibilityLabel == nil)
        } else {
            // Graceful placeholder if the figure isn't bundled.
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.1))
                .overlay(
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundColor(.secondary)
                )
                .accessibilityHidden(true)
        }
    }

    /// Resolves a loose bundle PNG by name. Tries the asset catalog first
    /// (in case it was imported), then a loose file URL.
    static func loadImage(named name: String) -> UIImage? {
        if let asset = UIImage(named: name) { return asset }
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
}
