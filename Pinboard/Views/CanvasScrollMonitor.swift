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
    let onInteractionChanged: (Bool) -> Void
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
        context.coordinator.update(
            isEnabled: isEnabled,
            topExclusion: topExclusion,
            excludedRects: excludedRects,
            onInteractionChanged: onInteractionChanged,
            onScroll: onScroll
        )
    }

    static func dismantleNSView(_ view: CanvasMonitorView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private enum ScrollOwner {
            case canvas
            case card
        }

        weak var view: CanvasMonitorView?

        private var isEnabled = false
        private var topExclusion: CGFloat = 0
        private var excludedRects: [CGRect] = []
        private var onInteractionChanged: ((Bool) -> Void)?
        private var onScroll: ((CanvasScrollEvent) -> Void)?

        private var monitor: Any?
        private var scrollOwner: ScrollOwner?
        private var interactionEndTask: Task<Void, Never>?
        private var isCanvasInteractionActive = false

        private let interactionSettleDelay = Duration.milliseconds(120)

        func update(
            isEnabled: Bool,
            topExclusion: CGFloat,
            excludedRects: [CGRect],
            onInteractionChanged: @escaping (Bool) -> Void,
            onScroll: @escaping (CanvasScrollEvent) -> Void
        ) {
            let shouldEndInteraction = self.isEnabled && !isEnabled
            self.isEnabled = isEnabled
            self.topExclusion = topExclusion
            self.excludedRects = excludedRects
            self.onInteractionChanged = onInteractionChanged
            self.onScroll = onScroll

            if shouldEndInteraction {
                Task { @MainActor [weak self] in
                    guard let self, !self.isEnabled else { return }
                    self.finishInteraction()
                }
            }
        }

        func attach(to view: CanvasMonitorView) {
            self.view = view
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
                [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func detach() {
            finishInteraction(notify: false)
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
            if scrollOwner == nil {
                guard view.bounds.contains(location), location.y >= topExclusion else {
                    return event
                }

                let zoomsCanvas = event.modifierFlags.contains(.command)
                let beginsOverCard = excludedRects.contains { $0.contains(location) }
                scrollOwner = zoomsCanvas || !beginsOverCard ? .canvas : .card
            }

            guard let scrollOwner else { return event }
            scheduleInteractionEnd(for: event)

            guard scrollOwner == .canvas else {
                return event
            }

            let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
            let translation = CGSize(
                width: event.scrollingDeltaX * multiplier,
                height: event.scrollingDeltaY * multiplier
            )
            let hasMovement = abs(translation.width) > 0.01
                || abs(translation.height) > 0.01

            if hasMovement || event.phase.contains(.began) {
                beginCanvasInteractionIfNeeded()
            }

            if hasMovement {
                onScroll?(
                    CanvasScrollEvent(
                        translation: translation,
                        location: location,
                        zoomsCanvas: event.modifierFlags.contains(.command)
                    )
                )
            }
            return nil
        }

        private func beginCanvasInteractionIfNeeded() {
            guard !isCanvasInteractionActive else { return }
            isCanvasInteractionActive = true
            onInteractionChanged?(true)
        }

        private func scheduleInteractionEnd(for event: NSEvent) {
            let isTerminal = event.phase.contains(.ended)
                || event.phase.contains(.cancelled)
                || event.momentumPhase.contains(.ended)
                || event.momentumPhase.contains(.cancelled)
            let isUnphasedEvent = event.phase.isEmpty && event.momentumPhase.isEmpty

            guard isTerminal || isUnphasedEvent else {
                interactionEndTask?.cancel()
                interactionEndTask = nil
                return
            }

            interactionEndTask?.cancel()
            interactionEndTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: interactionSettleDelay)
                guard !Task.isCancelled else { return }
                finishInteraction()
            }
        }

        private func finishInteraction(notify: Bool = true) {
            interactionEndTask?.cancel()
            interactionEndTask = nil
            scrollOwner = nil

            guard isCanvasInteractionActive else { return }
            isCanvasInteractionActive = false
            if notify {
                onInteractionChanged?(false)
            }
        }
    }
}

final class CanvasMonitorView: NSView {
    override var isFlipped: Bool { true }
}
