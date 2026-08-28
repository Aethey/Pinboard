//
//  CardKindIcon.swift
//  Pinboard
//

import SwiftUI

struct CardKindIcon: View {
    let kind: CardKind
    var size: CGFloat = 18
    var backgroundColor: Color = .primary.opacity(0.12)
    var foregroundColor: Color = .primary
    var borderColor: Color = .primary.opacity(0.14)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(backgroundColor)

            switch kind {
            case .text:
                Text("TXT")
                    .font(.system(size: size * 0.34, weight: .black, design: .rounded))
                    .tracking(-0.3)
            case .markdown:
                Text("M")
                    .font(.system(size: size * 0.56, weight: .black, design: .rounded))
            case .image:
                Image(systemName: "photo")
                    .font(.system(size: size * 0.52, weight: .semibold))
            }
        }
        .foregroundStyle(foregroundColor)
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(borderColor, lineWidth: 0.75)
        }
        .accessibilityLabel(kind.title)
    }
}
