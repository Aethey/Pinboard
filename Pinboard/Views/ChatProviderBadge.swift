//
//  ChatProviderBadge.swift
//  Pinboard
//

import SwiftUI

struct ChatProviderBadge: View {
    let provider: ChatProvider
    var size: CGFloat = PinboardTheme.Controls.cardIconSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(.white.opacity(0.94))

            providerIcon
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(.black.opacity(0.16), lineWidth: 0.75)
        }
        .accessibilityLabel("\(provider.title) conversation")
    }

    @ViewBuilder
    private var providerIcon: some View {
        if let assetName = providerAssetName {
            Image(assetName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: size * providerIconScale, height: size * providerIconScale)
        } else {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: size * 0.50, weight: .semibold))
                .foregroundStyle(PinboardTheme.selection)
        }
    }

    private var providerAssetName: String? {
        switch provider {
        case .chatGPT:
            "ProviderChatGPT"
        case .claude:
            "ProviderClaude"
        case .gemini:
            "ProviderGemini"
        case .cursor:
            "ProviderCursor"
        case .codex:
            "ProviderCodex"
        case .other:
            nil
        }
    }

    private var providerIconScale: CGFloat {
        switch provider {
        case .chatGPT, .claude, .gemini, .cursor:
            0.72
        case .codex:
            0.86
        case .other:
            0.50
        }
    }
}
