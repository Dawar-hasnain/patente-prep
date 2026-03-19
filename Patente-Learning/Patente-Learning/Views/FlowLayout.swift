//
//  FlowLayout.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 30/11/25.
//

import SwiftUI

struct FlowLayout<Content: View>: View {
    let content: () -> Content
    let spacing: CGFloat = 6

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
    }

    func generateContent(in geo: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            content()
                .alignmentGuide(.leading) { dim in
                    if abs(width - dim.width) > geo.size.width {
                        width = 0
                        height -= dim.height + spacing
                    }
                    let result = width
                    width -= dim.width + spacing
                    return result
                }
                .alignmentGuide(.top) { dim in
                    let result = height
                    return result
                }
        }
    }
}
