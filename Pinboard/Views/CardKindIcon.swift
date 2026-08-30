//
//  CardKindIcon.swift
//  Pinboard
//

import SwiftUI

struct CardKindIcon: View {
    let kind: CardKind
    var size: CGFloat = 18
    var backgroundColor: Color? = nil
    var foregroundColor: Color? = nil
    var borderColor: Color? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(backgroundColor ?? kind.badgeBackgroundColor)

            switch kind {
            case .text:
                Text("TXT")
                    .font(.system(size: size * 0.34, weight: .black, design: .rounded))
                    .tracking(-0.3)
            case .markdown:
                Text("M")
                    .font(.system(size: size * 0.56, weight: .black, design: .rounded))
            case .chat:
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: size * 0.46, weight: .semibold))
            case .image:
                Image(systemName: "photo")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: size * 0.52, weight: .semibold))
            case .pdf:
                Image(systemName: "doc.richtext")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: size * 0.50, weight: .semibold))
            case .link:
                Image(systemName: "link")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: size * 0.50, weight: .semibold))
            }
        }
        .foregroundStyle(foregroundColor ?? kind.badgeForegroundColor)
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(
                    borderColor ?? kind.badgeForegroundColor.opacity(0.22),
                    lineWidth: 0.75
                )
        }
        .accessibilityLabel(kind.title)
    }
}
