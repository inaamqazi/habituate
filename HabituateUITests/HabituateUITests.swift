import XCTest

final class HabituateUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Helpers

    private func launch(samples: Bool = false, arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + (samples ? ["-seedSamples"] : []) + arguments
        app.launch()
        return app
    }

    private func addHabit(_ name: String, in app: XCUIApplication) {
        let addFirst = app.buttons["addFirstHabit"]
        if addFirst.waitForExistence(timeout: 3) {
            addFirst.tap()
        } else {
            app.buttons["addHabit"].tap()
        }
        let field = app.textFields["habitNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name)
        app.buttons["saveHabit"].tap()
        XCTAssertTrue(row(name, in: app).waitForExistence(timeout: 5), "Row for \(name) should appear")
    }

    private func row(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["habitRow.\(name)"]
    }

    /// Monday-based index of today, matching the app's cell identifiers.
    private var todayIndex: Int {
        (Calendar(identifier: .gregorian).component(.weekday, from: Date()) + 5) % 7
    }

    private func waitToDisappear(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Swipes up in the middle of the screen until the element is entirely on screen. `isHittable` alone
    /// isn't enough: it is true for a button cut off by the bottom edge, and tapping its centre then misses.
    /// (Dragging in the right-hand margin grabs the scroll indicator instead of scrolling the list.)
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !isFullyVisible(element, in: app) && attempts < 10 {
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
    }

    private func isFullyVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        element.exists && element.isHittable && app.windows.firstMatch.frame.contains(element.frame)
    }

    private func openEditor(for name: String, in app: XCUIApplication) {
        row(name, in: app).tap()
        let edit = app.buttons["editHabit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.textFields["habitNameField"].waitForExistence(timeout: 5))
    }

    private func deleteFromEditor(in app: XCUIApplication) {
        let delete = app.buttons["deleteHabit"]
        scrollTo(delete, in: app)
        delete.tap()
        let confirm = app.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
    }

    // MARK: Tests

    func testEmptyStateThenAddHabit() {
        let app = launch()
        XCTAssertTrue(app.buttons["addFirstHabit"].waitForExistence(timeout: 5))
        addHabit("Stretch", in: app)
        XCTAssertFalse(app.buttons["addFirstHabit"].exists)
    }

    func testSaveIsDisabledUntilNameEntered() {
        let app = launch()
        app.buttons["addFirstHabit"].tap()
        let save = app.buttons["saveHabit"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        let field = app.textFields["habitNameField"]
        field.tap()
        field.typeText("Walk")
        XCTAssertTrue(save.isEnabled)
    }

    func testTickAndUntickTodayCell() {
        let app = launch()
        addHabit("Stretch", in: app)
        let cell = app.buttons["cell.Stretch.\(todayIndex)"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertEqual(cell.value as? String, "Not done")
        cell.tap()
        XCTAssertEqual(cell.value as? String, "Done")
        cell.tap()
        XCTAssertEqual(cell.value as? String, "Not done")
    }

    func testDaysBeforeAHabitStartedCannotBeTicked() throws {
        let app = launch()
        addHabit("Stretch", in: app)
        guard todayIndex > 0 else { throw XCTSkip("Today is Monday, so this week has no earlier day.") }
        let monday = app.buttons["cell.Stretch.0"]
        XCTAssertEqual(monday.value as? String, "Not scheduled")
        XCTAssertFalse(monday.isEnabled)
    }

    func testCompleteTodayMarksEveryHabit() {
        let app = launch()
        addHabit("Stretch", in: app)
        addHabit("Read", in: app)
        app.buttons["completeToday"].tap()
        XCTAssertEqual(app.buttons["cell.Stretch.\(todayIndex)"].value as? String, "Done")
        XCTAssertEqual(app.buttons["cell.Read.\(todayIndex)"].value as? String, "Done")
    }

    func testNavigateWeeks() {
        let app = launch(samples: true)
        let range = app.staticTexts["weekRange"]
        XCTAssertTrue(range.waitForExistence(timeout: 5))
        let thisWeek = range.label
        XCTAssertFalse(app.buttons["nextWeek"].isEnabled)
        XCTAssertFalse(app.buttons["todayButton"].isEnabled)

        app.buttons["previousWeek"].tap()
        XCTAssertNotEqual(range.label, thisWeek)
        XCTAssertTrue(app.buttons["nextWeek"].isEnabled)
        XCTAssertTrue(app.buttons["todayButton"].isEnabled)

        app.buttons["previousWeek"].tap()
        app.buttons["todayButton"].tap()
        XCTAssertEqual(range.label, thisWeek)

        app.buttons["previousWeek"].tap()
        app.buttons["nextWeek"].tap()
        XCTAssertEqual(range.label, thisWeek)
    }

    func testEditHabitName() {
        let app = launch()
        addHabit("Stretch", in: app)
        openEditor(for: "Stretch", in: app)
        let field = app.textFields["habitNameField"]
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        field.typeText("Yoga")
        app.buttons["saveHabit"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(row("Yoga", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("Stretch", in: app).exists)
    }

    func testEditScheduleKeepsTodaysTick() {
        let app = launch()
        addHabit("Stretch", in: app)
        app.buttons["cell.Stretch.\(todayIndex)"].tap()
        openEditor(for: "Stretch", in: app)
        let specificDays = app.buttons["Specific days"]
        scrollTo(specificDays, in: app)
        specificDays.tap()
        // Turn off a day other than today; today's tick must survive.
        let otherDay = (todayIndex + 1) % 7
        app.buttons["weekday.\(otherDay)"].tap()
        app.buttons["saveHabit"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertEqual(app.buttons["cell.Stretch.\(todayIndex)"].value as? String, "Done")
    }

    func testDeleteHabitWithUndo() {
        let app = launch()
        addHabit("Stretch", in: app)
        openEditor(for: "Stretch", in: app)
        deleteFromEditor(in: app)

        XCTAssertTrue(waitToDisappear(row("Stretch", in: app), timeout: 5))
        let undo = app.buttons["undoDelete"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertTrue(row("Stretch", in: app).waitForExistence(timeout: 5))
    }

    func testDeleteHabitPermanently() {
        let app = launch()
        addHabit("Stretch", in: app)
        openEditor(for: "Stretch", in: app)
        deleteFromEditor(in: app)

        XCTAssertTrue(app.buttons["undoDelete"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitToDisappear(app.buttons["undoDelete"], timeout: 12), "Undo banner goes away by itself")
        XCTAssertTrue(app.buttons["addFirstHabit"].waitForExistence(timeout: 5))
    }

    func testDeleteFromManageScreen() {
        let app = launch(samples: true)
        app.buttons["moreMenu"].tap()
        app.buttons["Manage Habits"].tap()
        let manageRow = app.buttons["manageRow.Workout"]
        XCTAssertTrue(manageRow.waitForExistence(timeout: 5))
        manageRow.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        // The confirmation dialog adds a second "Delete" button; it is the last one.
        XCTAssertTrue(app.staticTexts["Delete this habit?"].waitForExistence(timeout: 5))
        let deleteButtons = app.buttons.matching(identifier: "Delete")
        deleteButtons.element(boundBy: deleteButtons.count - 1).tap()
        XCTAssertTrue(waitToDisappear(manageRow, timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertFalse(row("Workout", in: app).exists)
    }

    func testDeniedNotificationsAreExplained() {
        // Test launches never get notification permission, which behaves like the user saying no.
        let app = launch()
        app.buttons["addFirstHabit"].tap()
        // The name field is focused on open; close the keyboard so it doesn't cover the toggle.
        let field = app.textFields["habitNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("\n")
        XCTAssertTrue(waitToDisappear(app.keyboards.firstMatch, timeout: 5))
        let toggle = app.switches["reminderToggle"]
        scrollTo(toggle, in: app)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        // The note is added below the toggle, possibly off screen.
        let note = app.descendants(matching: .any)["notificationsDeniedNote"]
        scrollTo(note, in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Settings"].exists)
    }

    func testManyHabitsScrollAndLongNames() {
        let app = launch(samples: true)
        let longName = "Practise a really long habit name with emoji 🎻 to check wrapping"
        addHabit(longName, in: app)
        for index in 1...14 {
            app.buttons["addHabit"].tap()
            let field = app.textFields["habitNameField"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText("Habit \(index)")
            app.buttons["saveHabit"].tap()
        }
        let last = row("Habit 14", in: app)
        scrollTo(last, in: app)
        XCTAssertTrue(last.isHittable)
    }
}
