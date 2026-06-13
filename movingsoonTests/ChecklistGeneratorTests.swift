// ChecklistGeneratorTests.swift — Tests for checklist generation logic
import XCTest
import SwiftData
@testable import movingsoon_app

final class ChecklistGeneratorTests: XCTestCase {

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

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    private func makeMove(zip: String = "80202") -> Move {
        Move(anchorDate: Date().addingTimeInterval(30 * 86400),
             originZip: zip, destinationZip: zip,
             destinationStateBucket: "CO", destinationCityBucket: "DENVER")
    }

    private func makeProfile(flags: Set<LifestyleFlag> = []) -> LifestyleProfile {
        let profile = LifestyleProfile()
        profile.activeFlags = flags
        return profile
    }

    // MARK: - Always-included tasks

    func test_alwaysInclude_USPSPresent_forAmericanUser() {
        let move = makeMove()
        let profile = makeProfile(flags: [.isAmerican])
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        let titles = tasks.map { $0.title }
        XCTAssertTrue(titles.contains("USPS Mail Forwarding"), "USPS should always be included for US users")
    }

    func test_alwaysInclude_USPSExcluded_forCanadianUser() {
        let move = makeMove()
        let profile = makeProfile(flags: [.isCanadian])
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        let titles = tasks.map { $0.title }
        XCTAssertFalse(titles.contains("USPS Mail Forwarding"), "USPS should be excluded for Canadian users")
    }

    func test_alwaysInclude_CanadaPost_forCanadianUser() {
        let move = makeMove()
        let profile = makeProfile(flags: [.isCanadian])
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        let titles = tasks.map { $0.title }
        XCTAssertTrue(titles.contains("Canada Post Mail Forwarding"), "Canada Post should appear for Canadian users")
    }

    func test_alwaysInclude_primaryCareDoctor() {
        let move = makeMove()
        let profile = makeProfile()
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        XCTAssertTrue(tasks.contains { $0.title == "Primary Care Doctor" })
    }

    func test_alwaysInclude_employerHR() {
        let move = makeMove()
        let profile = makeProfile()
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        XCTAssertTrue(tasks.contains { $0.title == "Employer HR & Payroll Address" })
    }

    // MARK: - Conditional tasks

    func test_children_tasks_appear_withHasChildrenFlag() {
        let move = makeMove()
        let profile = makeProfile(flags: [.hasChildren])
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        XCTAssertTrue(tasks.contains { $0.title == "Children's School Enrollment" })
        XCTAssertTrue(tasks.contains { $0.title == "Pediatrician & Children's Records" })
    }

    func test_children_tasks_absent_withoutFlag() {
        let move = makeMove()
        let profile = makeProfile(flags: [])
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        XCTAssertFalse(tasks.contains { $0.title == "Children's School Enrollment" })
    }

    func test_pet_tasks_appear_withHasPetsFlag() {
        let move = makeMove()
        let profile = makeProfile(flags: [.hasPets])
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        XCTAssertTrue(tasks.contains { $0.title == "Veterinarian Records Transfer" })
    }

    func test_mortgage_task_appears_withHasMortgageFlag() {
        let move = makeMove()
        let profile = makeProfile(flags: [.hasMortgage])
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        XCTAssertTrue(tasks.contains { $0.title == "Mortgage Servicer" })
    }

    func test_ev_task_appears_withEVFlag() {
        let move = makeMove()
        let profile = makeProfile(flags: [.hasElectricVehicle])
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        XCTAssertTrue(tasks.contains { $0.title == "Tesla Account / MyEV Address" })
    }

    // MARK: - Institution tasks

    func test_institution_generatesTask_withJustName() {
        let move = makeMove()
        let profile = makeProfile()
        let fi = FinancialInstitution(name: "Wells Fargo", initials: "WF",
                                      colorHex: "#B7410E", type: .bank,
                                      websiteURL: URL(string: "https://wellsfargo.com"))
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [fi])
        let task = tasks.first { $0.institutionName == "Wells Fargo" }
        XCTAssertNotNil(task)
        XCTAssertEqual(task?.title, "Wells Fargo", "Institution task title should be just the name, no prefix")
        XCTAssertEqual(task?.priority, .critical)
        XCTAssertEqual(task?.poiCategory, .bank)
    }

    func test_institution_noPrefixInTitle() {
        let move = makeMove()
        let profile = makeProfile()
        let fi = FinancialInstitution(name: "Chase", initials: "CH",
                                      colorHex: "#117ACA", type: .bank, websiteURL: nil)
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [fi])
        let task = tasks.first { $0.institutionName == "Chase" }
        XCTAssertFalse(task?.title.hasPrefix("Update address") ?? false,
                       "Title should NOT start with 'Update address'")
    }

    func test_institution_investmentType_highPriority() {
        let move = makeMove()
        let profile = makeProfile()
        let fi = FinancialInstitution(name: "Fidelity", initials: "FI",
                                      colorHex: "#27AE60", type: .investment, websiteURL: nil)
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [fi])
        let task = tasks.first { $0.institutionName == "Fidelity" }
        XCTAssertEqual(task?.priority, .high)
        XCTAssertNil(task?.poiCategory, "Investment accounts don't have a POI category")
    }

    // MARK: - Hero task ordering

    func test_heroTask_isFirstInList() {
        let move = makeMove()
        let profile = makeProfile(flags: [.isAmerican])
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        XCTAssertTrue(tasks.first?.isHeroItem ?? false, "First task should be the hero item (USPS)")
    }

    func test_noHeroTask_forCanadianUser_canadaPostIsHero() {
        let move = makeMove()
        let profile = makeProfile(flags: [.isCanadian])
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        XCTAssertTrue(tasks.first?.isHeroItem ?? false, "Canada Post should be hero for Canadian users")
        XCTAssertEqual(tasks.first?.title, "Canada Post Mail Forwarding")
    }

    // MARK: - Task count sanity

    func test_minimumTaskCount_baselineAmericanUser() {
        let move = makeMove()
        let profile = makeProfile(flags: [.isAmerican])
        let tasks = ChecklistGenerator.generate(for: move, profile: profile, institutions: [])
        XCTAssertGreaterThan(tasks.count, 10, "Should generate at least 10 tasks for a baseline US user")
    }

    func test_taskCount_increasesWithMoreFlags() {
        let move = makeMove()
        let baseProfile = makeProfile(flags: [.isAmerican])
        let richProfile = makeProfile(flags: [.isAmerican, .hasChildren, .hasPets,
                                               .hasCar, .hasElectricVehicle, .hasMortgage])
        let baseTasks = ChecklistGenerator.generate(for: move, profile: baseProfile, institutions: [])
        let richTasks = ChecklistGenerator.generate(for: move, profile: richProfile, institutions: [])
        XCTAssertGreaterThan(richTasks.count, baseTasks.count,
                             "More lifestyle flags should produce more tasks")
    }
}
