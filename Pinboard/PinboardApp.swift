//
//  PinboardApp.swift
//  Pinboard
//
//  Created by Ry@ on 2026/08/27.
//

import SwiftData
import SwiftUI

@main
struct PinboardApp: App {
    @NSApplicationDelegateAdaptor(PinboardApplicationDelegate.self)
    private var applicationDelegate

    @State private var session = BoardSession()
    @State private var attachmentLibrary = AttachmentLibrary()

    var body: some Scene {
        Window("Pinboard", id: "main") {
            ContentView()
                .environment(session)
                .environment(attachmentLibrary)
        }
        .modelContainer(
            for: [BoardCard.self, PinboardBoard.self],
            isAutosaveEnabled: true,
            isUndoEnabled: true
        )
        .defaultSize(width: 1180, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandMenu("Board") {
                Button("Switch to \(session.mode == .board ? "Desktop" : "Board") Mode") {
                    session.toggleMode()
                }

                Divider()

                Toggle("Snap to Grid", isOn: Bindable(session).snapToGrid)
            }
        }

        Settings {
            PinboardSettingsView()
        }
    }
}
