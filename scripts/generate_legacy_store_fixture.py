#!/usr/bin/env python3
"""Generate synthetic migration data with the exact stored models from 7aff543.

Only stored declarations/initializers are extracted; computed properties do not
participate in SwiftData schemas. The helper runs separately with the production
module name, so the new application never registers old and new models together.
Requires macOS 14+, Xcode and the original commit in local git history.
"""
import argparse
import os
from pathlib import Path
import platform
import shutil
import sqlite3
import subprocess
import tempfile

COMMIT = "7aff543"


def prior_model(repo, name, commit=COMMIT):
    if commit is None:
        return (repo / "movingsoon.app" / "Models" / f"{name}.swift").read_text()
    return subprocess.check_output(["git", "show", f"{commit}:movingsoon.app/Models/{name}.swift"], cwd=repo, text=True)


def model_source(repo, commit=COMMIT):
    parts = ["import Foundation\nimport SwiftData\n"]
    for name in ["Move", "ChecklistTask"]:
        parts.append(prior_model(repo, name, commit).split("    // MARK: - Computed", 1)[0] + "}\n")
    profile = prior_model(repo, "LifestyleProfile", commit)
    parts.append(profile[profile.index("@Model\nfinal class LifestyleProfile"):].split("    // MARK: - Flag access", 1)[0] + "}\n")
    for name in ["FinancialInstitution", "VerificationEvent", "PendingSignal"]:
        parts.append(prior_model(repo, name, commit))
    parts.append('''
enum MovePhase: String { case active = "Active", archived = "Archived" }
enum TaskStatus: String { case toDo = "To Do", pendingVerification = "Pending", completed = "Completed" }
enum TaskCategory: String { case subscriptions = "Subscriptions", healthcare = "Healthcare", financial = "Financial", other = "Other" }
enum TaskPriority: String { case critical = "Critical", high = "High", medium = "Medium", low = "Low" }
enum ActionType: String { case manualDeepLink = "Manual Deep Link" }
enum VerificationMethod: String { case manualConfirm = "Manual Confirm" }

let storeURL = URL(fileURLWithPath: CommandLine.arguments[1])
let schema = Schema([Move.self, ChecklistTask.self, VerificationEvent.self,
                     PendingSignal.self, FinancialInstitution.self, LifestyleProfile.self])
let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: storeURL)])
let context = ModelContext(container)
context.autosaveEnabled = false
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/New_York")!
func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
}
let move = Move(anchorDate: date(2026, 12, 15), originZip: "10001", destinationZip: "90001",
                destinationStateBucket: "CA", destinationCityBucket: "LOS_ANGELES")
move.id = UUID(uuidString: "F0000000-0000-4000-8000-000000000001")!
context.insert(move)
let profile = LifestyleProfile()
profile.activeFlagsJSON = "[]"
profile.childrenAnswer = true
profile.childCount = 2
profile.managesUtilities = false
profile.move = move
move.lifestyleProfile = profile
context.insert(profile)
let institution = FinancialInstitution(name: "Fixture Bank", initials: "FB", colorHex: "#123456", type: .bank,
                                       websiteURL: URL(string: "https://example.com"))
institution.move = move
context.insert(institution)
move.institutions = [institution]
let task = ChecklistTask(title: "Legacy delivery — Family", category: .subscriptions, priority: .high,
                         tMinusDays: -7, deepLinkURL: URL(string: "https://example.com/account"))
task.id = UUID(uuidString: "F0000000-0000-4000-8000-000000000002")!
task.catalogItemID = "amazon"
task.accountProviderName = "Legacy delivery"
task.accountNickname = "Family"
task.nextShipmentDate = date(2026, 11, 2)
task.nextRenewalDate = date(2026, 11, 10)
task.accountReminderLeadDays = 3
task.statusRaw = "Completed"
task.move = move
context.insert(task)
let verification = VerificationEvent(method: .manualConfirm, notes: "Synthetic legacy confirmation")
verification.task = task
context.insert(verification)
task.verificationEvents = [verification]
let custom = ChecklistTask(title: "Legacy custom task", category: .healthcare, priority: .medium,
                           tMinusDays: -10, isUserAdded: true)
custom.id = UUID(uuidString: "F0000000-0000-4000-8000-000000000003")!
custom.customerNote = "Synthetic note retained through migration"
custom.absoluteDueDate = date(2026, 11, 9)
custom.isMuted = true
custom.move = move
context.insert(custom)
move.tasks = [task, custom]
try context.save()
print("Synthetic previous-schema store created.")
''')
    return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    output = args.output or repo / "movingsoon.appTests" / "Fixtures" / "Legacy-7aff543.store"
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="movingsoon-legacy-fixture-") as temporary:
        root = Path(temporary)
        source = root / "LegacyModels.swift"
        source.write_text(model_source(repo))
        executable = root / "legacy-store-generator"
        environment = os.environ.copy()
        environment["CLANG_MODULE_CACHE_PATH"] = str(root / "clang-cache")
        environment["SWIFT_MODULECACHE_PATH"] = str(root / "swift-cache")
        target = f"{platform.machine()}-apple-macosx14.0"
        subprocess.run(["xcrun", "swiftc", "-module-name", "movingsoon_app", "-target", target,
                        str(source), "-o", str(executable)], env=environment, check=True)
        store = root / "Legacy.store"
        subprocess.run([str(executable), str(store)], env=environment, check=True)
        # Consolidate committed WAL pages so the fixture is one portable SQLite file.
        with sqlite3.connect(store) as connection:
            connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
            connection.execute("PRAGMA journal_mode=DELETE")
        shutil.copyfile(store, output)
    print(f"Wrote {output.name} from commit {COMMIT}; contains synthetic data only.")


if __name__ == "__main__":
    main()
