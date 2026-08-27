//
//  EmptyBoardView.swift
//  Pinboard
//

import SwiftUI

struct EmptyBoardView: View {
    let onAddText: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.3.group.bubble.left")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(PinboardTheme.selection)

            Text("Your board is open")
                .font(.title2.weight(.semibold))

            Text("Place the information you need side by side instead of scrolling through it.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button("Create a text card", systemImage: "plus", action: onAddText)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(34)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }
}

