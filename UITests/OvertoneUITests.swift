import XCTest

final class OvertoneUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-ui-state"]
        app.launch()
    }

    private func key(_ midi: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "key-\(midi)").firstMatch
    }

    func testPlayDiscoverAndResume() {
        XCTAssertTrue(key(60).waitForExistence(timeout: 10))
        // A demonstration must not award a discovery.
        app.buttons["lesson-example"].tap()
        XCTAssertFalse(app.buttons["next-lesson"].exists)
        key(60).tap()
        XCTAssertTrue(app.buttons["next-lesson"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '261.63'")).firstMatch.exists)
        app.buttons["next-lesson"].tap()
        key(60).tap()
        key(64).tap()
        XCTAssertFalse(app.buttons["next-lesson"].exists)
        key(60).tap()
        key(62).tap()
        XCTAssertTrue(app.buttons["next-lesson"].waitForExistence(timeout: 3))
        app.buttons["next-lesson"].tap()
        let expectedTitle = app.staticTexts["lesson-title"].label
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertEqual(app.staticTexts["lesson-title"].label, expectedTitle)
        app.buttons["journey"].tap()
        XCTAssertTrue(app.staticTexts["2 / 10 DISCOVERIES"].waitForExistence(timeout: 3))
    }

    func testLabLayerAndSettings() {
        app.tabBars.buttons["Lab"].tap()
        app.buttons["Keep notes"].tap()
        key(60).tap()
        key(67).tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'fifth' OR label CONTAINS 'Fifth'")).firstMatch.waitForExistence(timeout: 3))
        app.buttons["settings"].tap()
        XCTAssertTrue(app.switches["Sound on"].waitForExistence(timeout: 3))
        // SwiftUI exposes a labelled row and its actual UISwitch separately.
        // Tap the native control rather than the centre of the Form row.
        app.switches["Sound on"].descendants(matching: .switch).firstMatch.tap()
        app.switches["Haptics"].descendants(matching: .switch).firstMatch.tap()
        XCTAssertEqual(app.switches["Sound on"].value as? String, "0")
        XCTAssertEqual(app.switches["Haptics"].value as? String, "0")
        app.buttons["Done"].tap()
        key(60).tap()
        app.buttons["settings"].tap()
        XCTAssertEqual(app.switches["Sound on"].value as? String, "0")
        XCTAssertEqual(app.switches["Haptics"].value as? String, "0")
    }

    func testEarPracticeRespondsToPlayedNote() {
        app.tabBars.buttons["Practice"].tap()
        app.buttons["ear-new"].tap()
        key(60).tap()
        let feedback = app.staticTexts["ear-feedback"].label
        XCTAssertTrue(feedback.contains("You found") || feedback.contains("lower") || feedback.contains("higher"))
    }
}
