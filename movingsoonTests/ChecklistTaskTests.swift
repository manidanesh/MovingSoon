// ChecklistTaskTests.swift — Tests for task state machine and model logic
import XCTest
import SwiftData
@testable import movingsoon_app

final class ChecklistTaskTests: XCTestCase {

    private func makeTask() -> ChecklistTask {
        ChecklistTask(title: "Test Task", category: .financial, priority: .medium, tMinusDays: 0)
    }

    // MARK: - State machine

    func test_initialStatus_isToDo() {
        let task = makeTask()
        XCTAssertEqual(task.status, .toDo)
    }

    func test_advanceStatus_toDoToPendingVerification() {
        let task = makeTask()
        task.advanceStatus()
        XCTAssertEqual(task.status, .pendingVerification)
    }

    func test_advanceStatus_pendingToCompleted() {
        let task = makeTask()
        task.advanceStatus() // toDo → pending
        task.advanceStatus() // pending → completed
        XCTAssertEqual(task.status, .completed)
    }

    func test_advanceStatus_completedStaysCompleted() {
        let task = makeTask()
        task.advanceStatus()
        task.advanceStatus()
        task.advanceStatus() // should not crash or change
        XCTAssertEqual(task.status, .completed)
    }

    func test_advanceTwice_jumpsToCompleted() {
        let task = makeTask()
        task.advanceStatus()
        if task.status == .pendingVerification {
            task.advanceStatus()
        }
        XCTAssertEqual(task.status, .completed)
    }

    func test_resetStatus_fromCompleted_backToToDo() {
        let task = makeTask()
        task.advanceStatus()
        task.advanceStatus()
        task.resetStatus()
        XCTAssertEqual(task.status, .toDo)
    }

    func test_resetStatus_clearsVerificationEvents() {
        let task = makeTask()
        task.advanceStatus()
        task.advanceStatus() // completed — adds verification event
        XCTAssertFalse(task.verificationEvents.isEmpty)
        task.resetStatus()
        XCTAssertTrue(task.verificationEvents.isEmpty)
    }

    // MARK: - Category

    func test_categoryRawValue_roundtrips() {
        for category in TaskCategory.allCases {
            let task = ChecklistTask(title: "Test", category: category, priority: .medium, tMinusDays: 0)
            XCTAssertEqual(task.category, category, "Category \(category.rawValue) should round-trip correctly")
        }
    }

    // MARK: - Priority

    func test_priorityRawValue_roundtrips() {
        for priority in TaskPriority.allCases {
            let task = ChecklistTask(title: "Test", category: .other, priority: priority, tMinusDays: 0)
            XCTAssertEqual(task.priority, priority)
        }
    }

    // MARK: - POI category

    func test_poiCategory_nilByDefault() {
        let task = makeTask()
        XCTAssertNil(task.poiCategory)
    }

    func test_poiCategory_setAndRetrieved() {
        let task = makeTask()
        task.poiCategory = .bank
        XCTAssertEqual(task.poiCategory, .bank)
    }

    func test_poiCategory_clearedToNil() {
        let task = makeTask()
        task.poiCategory = .bank
        task.poiCategory = nil
        XCTAssertNil(task.poiCategory)
    }

    // MARK: - Mute & snooze

    func test_isMuted_falseByDefault() {
        XCTAssertFalse(makeTask().isMuted)
    }

    func test_snoozedUntil_nilByDefault() {
        XCTAssertNil(makeTask().snoozedUntil)
    }

    func test_deepLinkURL_roundtrips() {
        let url = URL(string: "https://www.wellsfargo.com")!
        let task = ChecklistTask(title: "WF", category: .financial, priority: .critical,
                                 tMinusDays: -14, deepLinkURL: url)
        XCTAssertEqual(task.deepLinkURL, url)
    }

    // MARK: - TaskCategory emoji

    func test_allCategories_haveEmoji() {
        for category in TaskCategory.allCases {
            let emoji = category.emoji
            XCTAssertFalse(emoji.isEmpty, "Category \(category.rawValue) should have an emoji")
        }
    }

    func test_allCategories_haveIcon() {
        for category in TaskCategory.allCases {
            let icon = category.icon
            XCTAssertFalse(icon.isEmpty, "Category \(category.rawValue) should have an SF symbol icon")
        }
    }
}
