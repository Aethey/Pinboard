//
//  ChatProviderBadge.swift
//  Pinboard
//

import SwiftUI

struct ChatProviderBadge: View {
    let provider: ChatProvider
    var height: CGFloat = PinboardTheme.Controls.cardIconSize

    var body: some View {
        Text(provider.title)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(height: height)
            .background(provider.badgeStyle)
            .clipShape(RoundedRectangle(cornerRadius: height * 0.28, style: .continuous))
            .accessibilityLabel("\(provider.title) conversation")
    }
}
