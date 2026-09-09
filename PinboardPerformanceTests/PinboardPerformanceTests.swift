//
//  PinboardPerformanceTests.swift
//  PinboardPerformanceTests
//

import XCTest

final class PinboardPerformanceTests: XCTestCase {
    private var app: XCUIApplication!

    private let primaryBoardID = "10000000-0000-0000-0000-000000000001"
    private let secondaryBoardID = "10000000-0000-0000-0000-000000000002"
    private let primaryCardID = "20000000-0000-0000-0000-000000000001"

    override func setUpWithError() throws {
        continueAfterFailure = false
        let profile = ProcessInfo.processInfo.environment["PINBOARD_PERFORMANCE_FIXTURE"]
            ?? (name.contains("testMarkdown") ? "markdown" : "normal")
        launch(profile: profile)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testBoardSwitchCycle() throws {
        let switcher = element("board-switcher")
        XCTAssertTrue(switcher.waitForExistence(timeout: 8))

        measureInteraction {
            self.selectBoard(id: self.secondaryBoardID)
            self.settle()
            self.selectBoard(id: self.primaryBoardID)
            self.settle()
        }
    }

    func testCardCollapseCycle() throws {
        let collapse = element("card-collapse-\(primaryCardID)")
        XCTAssertTrue(collapse.waitForExistence(timeout: 8))

        measureInteraction {
            collapse.click()
            self.settle(0.30)
            collapse.click()
            self.settle(0.30)
        }
    }

    func testSearchMorphCycle() throws {
        let openSearch = element("toolbar-search")
        XCTAssertTrue(openSearch.waitForExistence(timeout: 8))

        measureInteraction {
            openSearch.click()
            self.settle(0.45)
            let closeSearch = self.element("toolbar-search-close")
            XCTAssertTrue(closeSearch.waitForExistence(timeout: 2))
            closeSearch.click()
            self.settle(0.45)
        }
    }

    func testZoomCycle() throws {
        let zoomOut = element("canvas-zoom-out")
        let reset = element("canvas-zoom-reset")
        XCTAssertTrue(zoomOut.waitForExistence(timeout: 8))
        XCTAssertTrue(reset.exists)

        measureInteraction {
            zoomOut.click()
            zoomOut.click()
            self.settle(0.35)
            reset.click()
            self.settle(0.35)
        }
    }

    func testSelectAllZoomCycle() throws {
        let zoomOut = element("canvas-zoom-out")
        let reset = element("canvas-zoom-reset")
        XCTAssertTrue(zoomOut.waitForExistence(timeout: 8))
        XCTAssertTrue(reset.exists)

        app.typeKey("a", modifierFlags: .command)
        XCTAssertTrue(element("selection-fit-content").waitForExistence(timeout: 2))

        measureInteraction {
            zoomOut.click()
            zoomOut.click()
            self.settle(0.35)
            reset.click()
            self.settle(0.35)
        }
    }

    func testSelectAllFitContentCycle() throws {
        XCTAssertTrue(element("toolbar-search").waitForExistence(timeout: 8))

        app.typeKey("a", modifierFlags: .command)
        let fitContent = element("selection-fit-content")
        XCTAssertTrue(fitContent.waitForExistence(timeout: 2))

        measureInteraction {
            fitContent.click()
            self.settle(0.40)
        }
    }

    func testCardDragCycle() throws {
        let card = element("card-drag-\(primaryCardID)")
        XCTAssertTrue(card.waitForExistence(timeout: 8))

        measureInteraction {
            let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.08))
            let end = start.withOffset(CGVector(dx: 120, dy: 72))
            start.press(forDuration: 0.08, thenDragTo: end)
            self.settle(0.20)

            let movedStart = card.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.08))
            let movedEnd = movedStart.withOffset(CGVector(dx: -120, dy: -72))
            movedStart.press(forDuration: 0.08, thenDragTo: movedEnd)
            self.settle(0.20)
        }
    }

    func testMarkdownScrollCycle() throws {
        // Use PINBOARD_PERFORMANCE_FIXTURE=markdown for the long-document workload.
        let preview = element("markdown-scroll-\(primaryCardID)")
        XCTAssertTrue(preview.waitForExistence(timeout: 8))
        settle(1)
        measureInteraction {
            preview.scroll(byDeltaX: 0, deltaY: -500)
            self.settle(0.25)
            preview.scroll(byDeltaX: 0, deltaY: 500)
            self.settle(0.25)
        }
    }

    func testMarkdownCanvasPanCycle() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(element("markdown-scroll-\(primaryCardID)").waitForExistence(timeout: 8))
        settle(1)
        // The left margin is clear of cards in the markdown fixture.
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.75))
        let end = start.withOffset(CGVector(dx: 0, dy: -140))
        measureInteraction {
            start.press(forDuration: 0.05, thenDragTo: end)
            self.settle(0.25)
            end.press(forDuration: 0.05, thenDragTo: start)
            self.settle(0.25)
        }
    }

    private func launch(profile: String) {
        app = XCUIApplication()
        app.launchEnvironment["PINBOARD_PERFORMANCE_TESTING"] = "1"
        app.launchEnvironment["PINBOARD_PERFORMANCE_FIXTURE"] = profile
        if let motion = ProcessInfo.processInfo.environment["PINBOARD_MOTION"] {
            app.launchEnvironment["PINBOARD_MOTION"] = motion
        }
        app.launchArguments = [
            "--performance-testing",
            "--performance-fixture", profile,
        ]
        app.launch()
        app.activate()
        if !app.windows.firstMatch.waitForExistence(timeout: 2) {
            app.typeKey("n", modifierFlags: .command)
        }
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 12))
        if !element("toolbar-search").waitForExistence(timeout: 3) {
            print(app.debugDescription)
        }
    }

    private func measureInteraction(_ interaction: @escaping () -> Void) {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(
            metrics: [
                XCTHitchMetric(application: app),
                XCTCPUMetric(application: app),
                XCTMemoryMetric(application: app),
            ],
            options: options,
            block: interaction
        )
    }

    private func selectBoard(id: String) {
        let switcher = element("board-switcher")
        switcher.click()
        let board = element("board-\(id)")
        XCTAssertTrue(board.waitForExistence(timeout: 2))
        board.click()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func settle(_ duration: TimeInterval = 0.40) {
        Thread.sleep(forTimeInterval: duration)
    }
}
