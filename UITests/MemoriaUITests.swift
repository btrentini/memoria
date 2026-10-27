import XCTest

@MainActor final class MemoriaUITests:XCTestCase {
    func testNavigationAndQuickWindow() {
        let app=XCUIApplication()
        app.launchArguments=["-simplifiedView","NO"]
        app.launch()
        XCTAssertTrue(app.windows["Memoria"].waitForExistence(timeout:10))
        for (title,context) in [("Overview","overview"),("Applications","applications"),("CPU","cpu"),("Memory","memory"),("GPU & Neural Engine","gpu"),("Storage","storage"),("Network","network"),("Ports","ports"),("Power & Thermals","power"),("History","history"),("Diagnostics","diagnostics"),("Processes","processes")] {
            let item=app.outlines.staticTexts[title].firstMatch
            if item.waitForExistence(timeout:2) {item.click()} else {XCTFail("Missing navigation item: \(title)")}
            XCTAssertTrue(app.tables["process-ranking-"+context].waitForExistence(timeout:3),"Missing process ranking in \(title)")
        }
        let search=app.textFields["process-search"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout:3))
        search.click();search.typeText("Memoria")
        app.typeKey("k",modifierFlags:[.command,.shift])
        XCTAssertTrue(app.windows["Quick Task Manager"].waitForExistence(timeout:3))
        app.terminate()
    }
    func testSimpleViewAndReturnToFull() {
        let app=XCUIApplication()
        app.launchArguments=["-simplifiedView","NO"]
        app.launch()
        XCTAssertTrue(app.windows["Memoria"].waitForExistence(timeout:10))
        app.outlines.staticTexts["Memory"].firstMatch.click()
        let mode=app.segmentedControls["monitor-view-mode"]
        XCTAssertTrue(mode.waitForExistence(timeout:3))
        mode.buttons["Simple"].click()
        let summary=app.descendants(matching:.any).matching(identifier:"simple-top-processes-memory").firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout:3))
        XCTAssertLessThanOrEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","simple-process-row-")).count,10)
        XCTAssertFalse(app.tables["process-ranking-memory"].exists)
        mode.buttons["Full"].click()
        XCTAssertTrue(app.tables["process-ranking-memory"].waitForExistence(timeout:3))
        app.terminate()
    }
}
