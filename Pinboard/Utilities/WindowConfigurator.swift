//
//  WindowConfigurator.swift
//  Pinboard
//

import AppKit
import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    let mode: BoardMode

    func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        configureWindow(for: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.mode = mode
        configureWindow(for: nsView, coordinator: context.coordinator)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    private func configureWindow(for view: NSView, coordinator: Coordinator) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }

            coordinator.startMonitoring(window: window)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = false
            window.hasShadow = false
            window.collectionBehavior = [.managed, .fullScreenNone]
            window.level = mode == .desktop ? .floating : .normal
            window.ignoresMouseEvents = mode == .desktop
        }
    }

    final class Coordinator {
        var mode: BoardMode

        private weak var monitoredWindow: NSWindow?
        private var mouseMonitor: Any?

        init(mode: BoardMode) {
            self.mode = mode
        }

        func startMonitoring(window: NSWindow) {
            guard monitoredWindow !== window || mouseMonitor == nil else { return }

            stopMonitoring()
            monitoredWindow = window
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) {
                [weak self, weak window] event in
                guard
                    let self,
                    let window,
                    mode == .board,
                    event.window === window,
                    event.clickCount == 2,
                    event.locationInWindow.x >= 76,
                    event.locationInWindow.y >= window.frame.height - 30
                else { return event }

                window.performZoom(nil)
                return nil
            }
        }

        func stopMonitoring() {
            guard let mouseMonitor else { return }
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
            monitoredWindow = nil
        }
    }
}
