import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ChecklistFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupError.invalid }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum BackupError: LocalizedError {
    case invalid, unsupported, tooLarge
    var errorDescription: String? {
        switch self {
        case .invalid: return "This isn't a valid MovingSoon backup. Your existing moves have not changed."
        case .unsupported: return "This backup uses a newer format. Update MovingSoon before restoring it."
        case .tooLarge: return "This backup is too large to restore. Your existing moves have not changed."
        }
    }
}

/// A versioned, human-readable backup. Consent is intentionally never restored.
struct MoveBackup: Codable {
    var format = "app.movingsoon.backup"
    var version = 1
    var exportedAt = Date()
    var moves: [MoveRecord]
    struct MoveRecord: Codable {
        var fields: [String: String]
        var profile: [String: String]?
        var institutions: [[String: String]]
        var tasks: [TaskRecord]
    }
    struct TaskRecord: Codable {
        var fields: [String: String]
        var events: [[String: String]]
    }
}

@MainActor enum MoveBackupService {
    static let maximumFileSize = 20_000_000
    static let maximumVerificationEvents = 20_000

    /// Bound the read itself, including files whose metadata reports no size.
    static func readBackup(at url: URL) throws -> MoveBackup {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumFileSize + 1) ?? Data()
        return try decode(data)
    }

    static func export(_ moves: [Move]) throws -> Data {
        let records = moves.map { move -> MoveBackup.MoveRecord in
            var f: [String: String] = ["anchorDate": String(move.effectiveAnchorDate.timeIntervalSince1970),
                "destinationZip": move.destinationZip, "createdAt": String(move.createdAt.timeIntervalSince1970),
                "phaseRaw": move.phaseRaw]
            f["anchorDateOnly"] = move.anchorDateOnly
            f["originZip"] = move.originZip
            f["originNeighborhood"] = move.originNeighborhood
            f["destinationNeighborhood"] = move.destinationNeighborhood
            f["originLatitude"] = move.originLatitude.map { String($0) }
            f["originLongitude"] = move.originLongitude.map { String($0) }
            f["destinationLatitude"] = move.destinationLatitude.map { String($0) }
            f["destinationLongitude"] = move.destinationLongitude.map { String($0) }
            f["serviceResponsesJSON"] = move.serviceResponsesJSON
            f["reviewedFamiliesJSON"] = move.reviewedFamiliesJSON
            f["serviceUseResponsesJSON"] = move.serviceUseResponsesJSON
            f["areaInsightsEnabled"] = move.areaInsightsEnabled.map(String.init)
            f["completionCelebratedAt"] = move.completionCelebratedAt.map { String($0.timeIntervalSince1970) }
            var profile: [String: String]?
            if let p = move.lifestyleProfile {
                var pf = ["activeFlagsJSON": p.activeFlagsJSON]
                pf["signalRecordsJSON"] = p.signalRecordsJSON
                pf["childCount"] = p.childCount.map(String.init)
                pf["petSpeciesJSON"] = p.petSpeciesJSON
                pf["moveImpactFeedbackJSON"] = p.moveImpactFeedbackJSON
                pf["childrenAnswer"] = p.childrenAnswer.map(String.init)
                pf["petsAnswer"] = p.petsAnswer.map(String.init)
                pf["householdSize"] = p.householdSize.map(String.init)
                pf["originHousingRaw"] = p.originHousingRaw
                pf["destinationHousingRaw"] = p.destinationHousingRaw
                pf["homeKindRaw"] = p.homeKindRaw
                pf["managesUtilities"] = p.managesUtilities.map(String.init)
                profile = pf
            }
            let institutions = move.institutions.map { institution -> [String: String] in
                var values = ["name": institution.name, "initials": institution.initials,
                    "colorHex": institution.colorHex, "typeRaw": institution.typeRaw]
                values["websiteURLString"] = institution.websiteURLString
                return values
            }
            let tasks = move.tasks.map { task -> MoveBackup.TaskRecord in
                var tf = ["title": task.title, "categoryRaw": task.categoryRaw, "priorityRaw": task.priorityRaw,
                    "tMinusDays": String(task.tMinusDays), "statusRaw": task.statusRaw,
                    "isUserAdded": String(task.isUserAdded), "isHeroItem": String(task.isHeroItem),
                    "actionTypeRaw": task.actionTypeRaw, "isMuted": String(task.isMuted)]
                tf["deepLinkURLString"] = task.deepLinkURLString
                tf["assignee"] = task.assignee
                tf["catalogItemID"] = task.catalogItemID
                tf["moveActionRaw"] = task.moveActionRaw
                tf["customerNote"] = task.customerNote
                tf["needsLocationReview"] = task.needsLocationReview.map(String.init)
                tf["accountProviderName"] = task.accountProviderName
                tf["accountNickname"] = task.accountNickname
                tf["accountBaseTitle"] = task.accountBaseTitle
                tf["shipment"] = task.shipmentDate().map { String($0.timeIntervalSince1970) }
                tf["renewal"] = task.renewalDate().map { String($0.timeIntervalSince1970) }
                tf["customDue"] = task.customDueDate().map { String($0.timeIntervalSince1970) }
                tf["nextShipmentDateOnly"] = task.nextShipmentDateOnly
                tf["nextRenewalDateOnly"] = task.nextRenewalDateOnly
                tf["absoluteDueDateOnly"] = task.absoluteDueDateOnly
                tf["accountReminderLeadDays"] = task.accountReminderLeadDays.map(String.init)
                tf["poiCategoryRaw"] = task.poiCategoryRaw
                tf["snoozedUntil"] = task.snoozedUntil.map { String($0.timeIntervalSince1970) }
                tf["institutionName"] = task.institutionName
                tf["institutionInitials"] = task.institutionInitials
                tf["institutionColorHex"] = task.institutionColorHex
                let events = task.verificationEvents.map { event -> [String: String] in
                    var ef = ["timestamp": String(event.timestamp.timeIntervalSince1970), "methodRaw": event.methodRaw]
                    ef["notes"] = event.notes
                    return ef
                }
                return MoveBackup.TaskRecord(fields: tf, events: events)
            }
            return MoveBackup.MoveRecord(fields: f, profile: profile, institutions: institutions, tasks: tasks)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(MoveBackup(moves: records))
        // Every backup we offer to save must also fit the supported restore format.
        _ = try decode(data)
        return data
    }

    static func decode(_ data: Data) throws -> MoveBackup {
        guard data.count <= maximumFileSize else { throw BackupError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: MoveBackup
        do { backup = try decoder.decode(MoveBackup.self, from: data) }
        catch { throw BackupError.invalid }
        guard backup.format == "app.movingsoon.backup" else { throw BackupError.invalid }
        guard backup.version == 1 else { throw BackupError.unsupported }
        guard !backup.moves.isEmpty else { throw BackupError.invalid }
        guard backup.moves.count <= 100,
              backup.moves.reduce(0, { $0 + $1.tasks.count }) <= 10_000 else { throw BackupError.tooLarge }
        // Bound object creation across the whole import, not only each task.
        // Small event dictionaries can otherwise expand into millions of models.
        var eventCount = 0
        for move in backup.moves {
            for task in move.tasks {
                eventCount += task.events.count
                guard eventCount <= maximumVerificationEvents else { throw BackupError.tooLarge }
            }
        }
        for move in backup.moves {
            try validateFields(move.fields)
            guard PostalCodeService.isValid(move.fields["destinationZip"] ?? ""),
                  date(move.fields["anchorDate"]) != nil, move.institutions.count <= 500 else { throw BackupError.invalid }
            if let origin = move.fields["originZip"], !PostalCodeService.isValid(origin) { throw BackupError.invalid }
            if let key = move.fields["anchorDateOnly"], DateOnly.date(from: key) == nil { throw BackupError.invalid }
            try validateCoordinates(move.fields, prefix: "origin")
            try validateCoordinates(move.fields, prefix: "destination")
            if let profile = move.profile {
                try validateFields(profile)
                if let flags = profile["activeFlagsJSON"] {
                    guard let data = flags.data(using: .utf8),
                          (try? JSONDecoder().decode([String].self, from: data)) != nil else { throw BackupError.invalid }
                }
                if let json = profile["signalRecordsJSON"] {
                    guard let data = json.data(using: .utf8), let signals = try? JSONDecoder().decode([Signal].self, from: data),
                          signals.count <= LifestyleFlag.allCases.count,
                          Set(signals.map(\.flag)).count == signals.count,
                          signals.allSatisfy({ $0.confidence.isFinite && (0...1).contains($0.confidence) }) else { throw BackupError.invalid }
                }
                for key in ["childCount", "householdSize"] {
                    if let raw = profile[key] {
                        guard let value = Int(raw), (0...100).contains(value) else { throw BackupError.invalid }
                    }
                }
            }
            for institution in move.institutions { try validateFields(institution) }
            for task in move.tasks {
                try validateFields(task.fields)
                guard let title = task.fields["title"], !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      title.count <= 1000, TaskCategory(rawValue: task.fields["categoryRaw"] ?? "") != nil,
                      TaskStatus(rawValue: task.fields["statusRaw"] ?? "") != nil,
                      TaskPriority(rawValue: task.fields["priorityRaw"] ?? "") != nil,
                      let offset = Int(task.fields["tMinusDays"] ?? ""), (-36_500...36_500).contains(offset),
                      task.events.count <= 1000 else { throw BackupError.invalid }
                for key in ["nextShipmentDateOnly", "nextRenewalDateOnly", "absoluteDueDateOnly"] {
                    if let value = task.fields[key], DateOnly.date(from: value) == nil { throw BackupError.invalid }
                }
                for key in ["shipment", "renewal", "customDue", "snoozedUntil"] {
                    if let value = task.fields[key], date(value) == nil { throw BackupError.invalid }
                }
                for event in task.events { try validateFields(event) }
            }
        }
        return backup
    }

    /// Import creates new identities and archived copies; it never overwrites progress.
    static func restore(_ backup: MoveBackup, in context: ModelContext) throws -> [Move] {
        // Revalidate even if called programmatically rather than through the file picker.
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        _ = try decode(encoder.encode(backup))
        var restored: [Move] = []
        for record in backup.moves {
            let f = record.fields
            let destination = PostalCodeService.normalize(f["destinationZip"] ?? "")
            let bucket = ZipBucketService.bucket(zip: destination)
            let move = Move(anchorDate: date(f["anchorDate"])!, originZip: f["originZip"],
                destinationZip: destination, destinationStateBucket: bucket.state, destinationCityBucket: bucket.city)
            move.anchorDateOnly = f["anchorDateOnly"] ?? move.anchorDateOnly
            move.originNeighborhood = f["originNeighborhood"]
            move.destinationNeighborhood = f["destinationNeighborhood"]
            move.originLatitude = f["originLatitude"].flatMap(Double.init)
            move.originLongitude = f["originLongitude"].flatMap(Double.init)
            move.destinationLatitude = f["destinationLatitude"].flatMap(Double.init)
            move.destinationLongitude = f["destinationLongitude"].flatMap(Double.init)
            move.createdAt = date(f["createdAt"]) ?? Date()
            move.phaseRaw = MovePhase.archived.rawValue
            move.serviceResponsesJSON = f["serviceResponsesJSON"]
            move.reviewedFamiliesJSON = f["reviewedFamiliesJSON"]
            move.serviceUseResponsesJSON = f["serviceUseResponsesJSON"]
            move.completionCelebratedAt = date(f["completionCelebratedAt"])
            move.areaInsightsEnabled = false // Restoring never opts someone into network lookups.
            context.insert(move)
            if let pf = record.profile {
                let profile = LifestyleProfile()
                profile.activeFlagsJSON = pf["activeFlagsJSON"] ?? "[]"
                profile.signalRecordsJSON = pf["signalRecordsJSON"]
                profile.childCount = pf["childCount"].flatMap(Int.init)
                profile.petSpeciesJSON = pf["petSpeciesJSON"]
                profile.moveImpactFeedbackJSON = pf["moveImpactFeedbackJSON"]
                profile.childrenAnswer = pf["childrenAnswer"].flatMap(Bool.init)
                profile.petsAnswer = pf["petsAnswer"].flatMap(Bool.init)
                profile.householdSize = pf["householdSize"].flatMap(Int.init)
                profile.originHousingRaw = pf["originHousingRaw"]
                profile.destinationHousingRaw = pf["destinationHousingRaw"]
                profile.homeKindRaw = pf["homeKindRaw"]
                profile.managesUtilities = pf["managesUtilities"].flatMap(Bool.init)
                profile.move = move; context.insert(profile); move.lifestyleProfile = profile
            }
            for fields in record.institutions {
                let institution = FinancialInstitution(name: fields["name"] ?? "Account", initials: fields["initials"] ?? "",
                    colorHex: fields["colorHex"] ?? "#626567", type: fields["typeRaw"].flatMap(InstitutionType.init(rawValue:)) ?? .bank,
                    websiteURL: safeURL(fields["websiteURLString"]))
                institution.move = move; context.insert(institution); move.institutions.append(institution)
            }
            for tr in record.tasks {
                let tf = tr.fields
                let task = ChecklistTask(title: tf["title"]!, category: TaskCategory(rawValue: tf["categoryRaw"]!)!,
                    priority: TaskPriority(rawValue: tf["priorityRaw"]!)!, tMinusDays: Int(tf["tMinusDays"]!)!,
                    isHeroItem: tf["isHeroItem"] == "true", deepLinkURL: safeURL(tf["deepLinkURLString"]),
                    isUserAdded: tf["isUserAdded"] == "true")
                task.statusRaw = tf["statusRaw"]!
                task.assignee = tf["assignee"]; task.catalogItemID = tf["catalogItemID"]
                task.moveActionRaw = tf["moveActionRaw"]; task.customerNote = tf["customerNote"]
                task.needsLocationReview = tf["needsLocationReview"].flatMap(Bool.init)
                task.accountProviderName = tf["accountProviderName"]; task.accountNickname = tf["accountNickname"]
                task.accountBaseTitle = tf["accountBaseTitle"]
                task.setShipmentDate(date(tf["shipment"])); task.setRenewalDate(date(tf["renewal"])); task.setCustomDueDate(date(tf["customDue"]))
                task.nextShipmentDateOnly = tf["nextShipmentDateOnly"] ?? task.nextShipmentDateOnly
                task.nextRenewalDateOnly = tf["nextRenewalDateOnly"] ?? task.nextRenewalDateOnly
                task.absoluteDueDateOnly = tf["absoluteDueDateOnly"] ?? task.absoluteDueDateOnly
                task.accountReminderLeadDays = tf["accountReminderLeadDays"].flatMap(Int.init).map { min(30, max(0, $0)) }
                task.actionTypeRaw = tf["actionTypeRaw"] ?? ActionType.manualDeepLink.rawValue
                task.poiCategoryRaw = tf["poiCategoryRaw"]
                task.isMuted = tf["isMuted"] == "true"; task.snoozedUntil = date(tf["snoozedUntil"])
                task.institutionName = tf["institutionName"]; task.institutionInitials = tf["institutionInitials"]
                task.institutionColorHex = tf["institutionColorHex"]
                task.move = move; context.insert(task); move.tasks.append(task)
                for ef in tr.events {
                    let event = VerificationEvent(method: ef["methodRaw"].flatMap(VerificationMethod.init(rawValue:)) ?? .manualConfirm, notes: ef["notes"])
                    event.timestamp = date(ef["timestamp"]) ?? Date(); event.task = task
                    context.insert(event); task.verificationEvents.append(event)
                }
            }
            restored.append(move)
        }
        do { try context.save() } catch { context.rollback(); throw error }
        return restored
    }

    private static func date(_ string: String?) -> Date? {
        guard let value = string.flatMap(Double.init), value.isFinite, abs(value) < 32_503_680_000 else { return nil }
        return Date(timeIntervalSince1970: value)
    }
    private static func validateFields(_ fields: [String: String]) throws {
        guard fields.count <= 100, fields.allSatisfy({ $0.key.count <= 100 && $0.value.utf8.count <= 200_000 }) else {
            throw BackupError.tooLarge
        }
    }
    private static func validateCoordinates(_ fields: [String: String], prefix: String) throws {
        let latitude = fields[prefix + "Latitude"], longitude = fields[prefix + "Longitude"]
        guard latitude != nil || longitude != nil else { return }
        guard let latitude, let longitude, let lat = Double(latitude), let lon = Double(longitude),
              lat.isFinite, lon.isFinite, (-90...90).contains(lat), (-180...180).contains(lon) else { throw BackupError.invalid }
    }
    private static func safeURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }

    static func checklistText(for move: Move) -> String {
        let lines = move.tasks.sorted { $0.isDueBefore($1, moveDate: move.effectiveAnchorDate) }.map { task in
            let due = task.dueDate(moveDate: move.effectiveAnchorDate).formatted(date: .abbreviated, time: .omitted)
            let owner = task.assignee.map { " · \($0)" } ?? ""
            let note = task.customerNote.flatMap { $0.isEmpty ? nil : "\n  \($0)" } ?? ""
            return "\(task.status == .completed ? "☑" : "☐") \(task.title) — \(due)\(owner)\(note)"
        }
        return (["MovingSoon address-change checklist", "Destination: \(move.destinationZip)",
            "Move date: \(move.effectiveAnchorDate.formatted(date: .abbreviated, time: .omitted))",
            "\(move.completedCount) of \(move.totalCount) completed", ""] + lines).joined(separator: "\n")
    }
}
