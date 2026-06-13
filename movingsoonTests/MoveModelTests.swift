// MoveModelTests.swift — Tests for Move model computed properties
import XCTest
import SwiftData
@testable import movingsoon_app

final class MoveModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([Move.self, ChecklistTask.self, VerificationEvent.self,
                             PendingSignal.self, FinancialInstitution.self, LifestyleProfile.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    private func makeMove(daysFromNow: Int = 30) -> Move {
        let anchor = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        return Move(anchorDate: anchor, originZip: "80202", destinationZip: "80202",
                    destinationStateBucket: "CO", destinationCityBucket: "DENVER")
    }

    // MARK: - daysUntilMove

    func test_daysUntilMove_futureDate_positive() {
        let move = makeMove(daysFromNow: 14)
        XCTAssertGreaterThan(move.daysUntilMove, 0)
    }

    func test_daysUntilMove_pastDate_negative() {
        let move = makeMove(daysFromNow: -7)
        XCTAssertLessThan(move.daysUntilMove, 0)
    }

    // MARK: - completionFraction

    func test_completionFraction_noTasks_isZero() {
        let move = makeMove()
        XCTAssertEqual(move.completionFraction, 0.0)
    }

    func test_completionFraction_allCompleted_isOne() {
        let move = makeMove()
        let task = ChecklistTask(title: "Test", category: .financial, priority: .medium, tMinusDays: 0)
        task.advanceStatus(); task.advanceStatus() // → completed
        task.move = move
        context.insert(task)
        move.tasks = [task]
        XCTAssertEqual(move.completionFraction, 1.0, accuracy: 0.001)
    }

    func test_completionFraction_halfCompleted() {
        let move = makeMove()
        let task1 = ChecklistTask(title: "Task 1", category: .financial, priority: .medium, tMinusDays: 0)
        let task2 = ChecklistTask(title: "Task 2", category: .financial, priority: .medium, tMinusDays: 0)
        task1.advanceStatus(); task1.advanceStatus() // completed
        move.tasks = [task1, task2]
        XCTAssertEqual(move.completionFraction, 0.5, accuracy: 0.001)
    }

    // MARK: - completedCount / totalCount

    func test_totalCount_matchesTaskArray() {
        let move = makeMove()
        move.tasks = [
            ChecklistTask(title: "A", category: .financial, priority: .medium, tMinusDays: 0),
            ChecklistTask(title: "B", category: .financial, priority: .medium, tMinusDays: 0),
        ]
        XCTAssertEqual(move.totalCount, 2)
    }

    func test_completedCount_onlyCountsCompleted() {
        let move = makeMove()
        let t1 = ChecklistTask(title: "A", category: .financial, priority: .medium, tMinusDays: 0)
        let t2 = ChecklistTask(title: "B", category: .financial, priority: .medium, tMinusDays: 0)
        t1.advanceStatus(); t1.advanceStatus()
        move.tasks = [t1, t2]
        XCTAssertEqual(move.completedCount, 1)
    }

    // MARK: - locationConsentGrantedAt

    func test_locationConsentGrantedAt_nilByDefault() {
        let move = makeMove()
        XCTAssertNil(move.locationConsentGrantedAt)
    }

    func test_locationConsentGrantedAt_canBeSet() {
        let move = makeMove()
        let date = Date()
        move.locationConsentGrantedAt = date
        XCTAssertNotNil(move.locationConsentGrantedAt)
    }
}
