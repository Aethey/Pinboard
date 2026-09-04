//
//  PinboardSettingsView.swift
//  Pinboard
//

import SwiftUI

struct PinboardSettingsView: View {
    @AppStorage(BoardBackgroundStyle.storageKey)
    private var boardBackgroundStyleRawValue = BoardBackgroundStyle.midnight.rawValue

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Board background", selection: $boardBackgroundStyleRawValue) {
                    ForEach(BoardBackgroundStyle.allCases) { style in
                        Label {
                            Text(style.title)
                        } icon: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [style.topColor, style.bottomColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    Circle().stroke(.white.opacity(0.16), lineWidth: 1)
                                }
                        }
                        .tag(style.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("board-background-picker")

                Text("Changes are applied immediately and remembered when Pinboard restarts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 300)
    }
}
