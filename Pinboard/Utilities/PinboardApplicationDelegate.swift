//
//  PinboardApplicationDelegate.swift
//  Pinboard
//

import AppKit

@MainActor
final class PinboardApplicationDelegate: NSObject, NSApplicationDelegate {
    private let mcpBridge = PinboardMCPBridge()

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard
            ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1",
            let bundleIdentifier = Bundle.main.bundleIdentifier
        else { return }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        guard let existingApplication = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: {
                !$0.isTerminated && $0.processIdentifier != currentProcessIdentifier
            })
        else { return }

        existingApplication.activate(options: [.activateAllWindows])
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        mcpBridge.start()
        applyApplicationIcon()

        // SwiftUI may finish configuring the Dock tile after this delegate
        // callback, so apply the icon once more on the next main-loop turn.
        DispatchQueue.main.async { [weak self] in
            self?.applyApplicationIcon()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        applyApplicationIcon()
    }

    private func applyApplicationIcon() {
        guard
            let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else { return }

        NSApp.applicationIconImage = icon
        NSApp.dockTile.display()
    }
}

extension Notification.Name {
    static let pinboardOpenDeepLink = Notification.Name(
        "rya.Pinboard.received-deep-link"
    )
}
