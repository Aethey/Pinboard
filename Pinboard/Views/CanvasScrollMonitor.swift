//
//  CanvasScrollMonitor.swift
//  Pinboard
//

import AppKit
import SwiftUI

struct CanvasScrollEvent {
    let translation: CGSize
    let location: CGPoint
    let zoomsCanvas: Bool
}

struct CanvasScrollMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let topExclusion: CGFloat
    let excludedRects: [CGRect]
    let onScroll: (CanvasScrollEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> CanvasMonitorView {
        let view = CanvasMonitorView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ view: CanvasMonitorView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.topExclusion = topExclusion
        context.coordinator.excludedRects = excludedRects
        context.coordinator.onScroll = onScroll
    }

    static func dismantleNSView(_ view: CanvasMonitorView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        weak var view: CanvasMonitorView?
        var isEnabled = false
        var topExclusion: CGFloat = 0
        var excludedRects: [CGRect] = []
        var onScroll: ((CanvasScrollEvent) -> Void)?

        private var monitor: Any?

        func attach(to view: CanvasMonitorView) {
            self.view = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
                [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            view = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard
                isEnabled,
                let view,
                let window = view.window,
                event.window === window
            else { return event }

            let location = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(location), location.y >= topExclusion else {
                return event
            }
            guard !excludedRects.contains(where: { $0.contains(location) }) else {
                return event
            }

            let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
            let translation = CGSize(
                width: event.scrollingDeltaX * multiplier,
                height: event.scrollingDeltaY * multiplier
            )
            guard abs(translation.width) > 0.01 || abs(translation.height) > 0.01 else {
                return event
            }

            onScroll?(
                CanvasScrollEvent(
                    translation: translation,
                    location: location,
                    zoomsCanvas: event.modifierFlags.contains(.command)
                )
            )
            return nil
        }
    }
}

final class CanvasMonitorView: NSView {
    override var isFlipped: Bool { true }
}
