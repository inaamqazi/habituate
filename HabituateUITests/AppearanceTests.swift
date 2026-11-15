import XCTest

/// Screenshots in light, dark and the largest text size, plus Xcode's automated accessibility audit.
/// CI runs these on a small and a large iPhone and uploads the screenshots for review.
final class AppearanceTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private static let largestText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-seedSamples"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["habitRow.Workout"].waitForExistence(timeout: 10))
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "Device"
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(device) - \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func captureAllScreens(_ app: XCUIApplication, variant: String) {
        capture(app, "\(variant) 1 Week")
        app.buttons["habitRow.Workout"].tap()
        XCTAssertTrue(app.buttons["editHabit"].waitForExistence(timeout: 5))
        capture(app, "\(variant) 2 Detail")
        app.buttons["editHabit"].tap()
        XCTAssertTrue(app.textFields["habitNameField"].waitForExistence(timeout: 5))
        capture(app, "\(variant) 3 Editor")
    }

    func testScreensLight() {
        captureAllScreens(launch(), variant: "Light")
    }

    func testScreensDark() {
        captureAllScreens(launch(["-darkMode"]), variant: "Dark")
    }

    func testScreensLargestText() {
        captureAllScreens(launch(Self.largestText), variant: "Largest text")
    }

    func testEmptyState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.buttons["addFirstHabit"].waitForExistence(timeout: 5))
        capture(app, "Empty state")
        try app.performAccessibilityAudit()
    }

    func testAccessibilityAuditWeek() throws {
        let app = launch()
        try app.performAccessibilityAudit()
    }

    func testAccessibilityAuditDetailAndEditor() throws {
        let app = launch()
        app.buttons["habitRow.Workout"].tap()
        XCTAssertTrue(app.buttons["editHabit"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
        app.buttons["editHabit"].tap()
        XCTAssertTrue(app.textFields["habitNameField"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    func testAccessibilityAuditLargestText() throws {
        let app = launch(Self.largestText)
        try app.performAccessibilityAudit()
    }
}
