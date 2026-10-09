import Foundation
import CoreLocation
import CryptoKit

struct LocationPlaceTarget: Equatable {
    let query: String
    let acceptedNames: [String]
    let category: POICategory

    func matches(name: String?) -> Bool {
        guard let name else { return false }
        let candidate = Self.normalized(name)
        return acceptedNames.contains { alias in
            let key = Self.normalized(alias)
            return key != " " && candidate.contains(key)
        }
    }

    private static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "&", with: " and ")
        return " " + folded.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ") + " "
    }

    @MainActor static func forTask(_ task: ChecklistTask) -> LocationPlaceTarget? {
        guard let category = task.poiCategory else { return nil }
        if let institution = task.institutionName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !institution.isEmpty {
            return LocationPlaceTarget(query: institution, acceptedNames: [institution], category: category)
        }
        guard let id = MoveChecklistService.catalogID(for: task), let item = ItemCatalog.byID[id] else { return nil }
        if let query = item.placeSearchName, !item.placeNameAliases.isEmpty {
            return LocationPlaceTarget(query: query, acceptedNames: item.placeNameAliases, category: category)
        }
        // Government offices and finding a new mechanic are category-level tasks.
        // Unknown personal doctors/gyms, multi-provider passes and airline accounts
        // remain checklist reminders until a specific relevant place is known.
        if ["dmv_license", "dmv_vehicle", "vehicle_inspection"].contains(id) {
            return LocationPlaceTarget(query: "DMV motor vehicle driver licensing office",
                acceptedNames: ["DMV", "Department of Motor Vehicles", "Motor Vehicle", "Driver License",
                                "Driver Services", "Secretary of State"], category: category)
        }
        if id == "auto_service_center" {
            return LocationPlaceTarget(query: "auto repair mechanic",
                acceptedNames: ["Auto Repair", "Automotive", "Mechanic", "Service Center"], category: category)
        }
        return nil
    }
}

struct LocationRegionRequest {
    let identifier: String
    let taskID: UUID
    let target: LocationPlaceTarget
}

enum LocationRegionPlan {
    @MainActor static func requests(for move: Move, destination: CLLocationCoordinate2D,
                                    now: Date = Date()) -> [LocationRegionRequest] {
        move.tasks.filter { ReminderPolicy.isEligible($0, at: now) }
            .sorted { $0.isDueBefore($1, moveDate: move.anchorDate) }
            .compactMap { task in
                guard let target = LocationPlaceTarget.forTask(task) else { return nil }
                if let id = MoveChecklistService.catalogID(for: task), let item = ItemCatalog.byID[id],
                   !PostalCodeService.canReview(item, contexts: [PostalCodeService.regionalFlags(for: move.destinationZip)]) {
                    return nil
                }
                let signature = [move.id.uuidString, move.destinationZip, String(destination.latitude),
                                 String(destination.longitude), target.query, target.acceptedNames.joined(separator: ",")]
                    .joined(separator: "|")
                let hash = SHA256.hash(data: Data(signature.utf8)).prefix(10).map { String(format: "%02x", $0) }.joined()
                return LocationRegionRequest(identifier: "loc2|\(task.id.uuidString)|\(hash)", taskID: task.id, target: target)
            }
    }
}
