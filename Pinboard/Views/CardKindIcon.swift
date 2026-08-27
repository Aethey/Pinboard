//
//  CardKindIcon.swift
//  Pinboard
//

import SwiftUI

struct CardKindIcon: View {
    let kind: CardKind
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(.primary.opacity(0.07))

            switch kind {
            case .text:
                Text("TXT")
                    .font(.system(size: size * 0.36, weight: .black, design: .rounded))
                    .tracking(-0.35)
            case .markdown:
                Text("M")
                    .font(.system(size: size * 0.62, weight: .black, design: .rounded))
            case .image:
                Image(systemName: "photo")
                    .font(.system(size: size * 0.58, weight: .semibold))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(kind.title)
    }
}
