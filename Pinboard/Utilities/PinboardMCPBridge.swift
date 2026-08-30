//
//  PinboardMCPBridge.swift
//  Pinboard
//

import AppKit
import Network

@MainActor
final class PinboardMCPBridge {
    private static let port: NWEndpoint.Port = 17_373
    private static let maximumRequestBytes = 96 * 1_024

    private let queue = DispatchQueue(label: "rya.Pinboard.mcp-bridge")
    private var listener: NWListener?

    func start() {
        guard listener == nil else { return }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            let listener = try NWListener(using: parameters, on: Self.port)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.accept(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                guard case .failed = state else { return }
                Task { @MainActor in
                    self?.listener?.cancel()
                    self?.listener = nil
                }
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            listener = nil
        }
    }

    private func accept(_ connection: NWConnection) {
        guard isLoopback(connection.endpoint) else {
            connection.cancel()
            return
        }

        connection.start(queue: queue)
        receive(from: connection, accumulatedData: Data())
    }

    private func isLoopback(_ endpoint: NWEndpoint) -> Bool {
        guard case let .hostPort(host, _) = endpoint else { return false }
        return host == .ipv4(.loopback)
            || host == .ipv6(.loopback)
            || host == "localhost"
    }

    private func receive(
        from connection: NWConnection,
        accumulatedData: Data
    ) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 16 * 1_024
        ) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else {
                    connection.cancel()
                    return
                }

                var requestData = accumulatedData
                if let data {
                    requestData.append(data)
                }

                guard requestData.count <= Self.maximumRequestBytes else {
                    connection.cancel()
                    return
                }

                if let newlineIndex = requestData.firstIndex(of: 0x0A) {
                    let lineData = requestData[..<newlineIndex]
                    self.handle(lineData, on: connection)
                } else if isComplete || error != nil {
                    connection.cancel()
                } else {
                    self.receive(
                        from: connection,
                        accumulatedData: requestData
                    )
                }
            }
        }
    }

    private func handle(_ data: Data.SubSequence, on connection: NWConnection) {
        guard
            let value = String(data: data, encoding: .utf8),
            let url = URL(string: value),
            url.scheme?.lowercased() == PinboardDeepLink.scheme,
            (try? PinboardDeepLink.request(from: url)) != nil
        else {
            connection.cancel()
            return
        }

        NotificationCenter.default.post(
            name: .pinboardOpenDeepLink,
            object: url
        )
        NSApp.activate(ignoringOtherApps: true)

        connection.send(content: Data("OK\n".utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
