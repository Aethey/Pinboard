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
    }
}

extension Notification.Name {
    static let pinboardOpenDeepLink = Notification.Name(
        "rya.Pinboard.received-deep-link"
    )
}
