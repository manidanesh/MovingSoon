import SwiftUI
import SwiftData

/// Read-only recovery export never replaces or deletes an unreadable database.
struct StoreRecoveryView: View {
    let storeURL: URL
    let retry: () -> ModelContainer?
    @State private var recovered: ModelContainer?
    @State private var delegate: NotificationDelegate?
    @State private var document = ChecklistFile()
    @State private var exporting = false
    @State private var message: String?

    var body: some View {
        if let recovered {
            ContentView().modelContainer(recovered)
        } else {
            ScrollView {
              VStack(spacing: 18) {
                Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                Text("Your saved checklist couldn’t open").font(.title2.weight(.semibold))
                Text("Your data has been kept. Try again after checking available storage or restarting your phone. Save a recovery copy before reinstalling.")
                    .foregroundStyle(.secondary)
                Button("Try opening again") {
                    guard let container = retry() else {
                        message = "Your saved data still couldn't open. Export a recovery copy and contact support."
                        return
                    }
                    container.mainContext.autosaveEnabled = false
                    delegate = NotificationDelegate(container: container)
                    UNUserNotificationCenter.current().delegate = delegate
                    LocationManager.shared.configure(context: container.mainContext)
                    recovered = container
                }.buttonStyle(.borderedProminent)
                Button("Export recovery copy") {
                    do {
                        document = ChecklistFile(data: try StoreRecoveryService.export(storeURL: storeURL))
                        exporting = true
                    } catch { message = "The recovery copy couldn't be read. Your original files are still intact. Contact support before reinstalling." }
                }
                Text("Recovery copies may contain private account names, notes and household details. They are for recovery support, not the normal backup restore flow. Nothing is sent automatically.")
                    .font(.caption).foregroundStyle(.secondary)
                Link("Support website", destination: SupportLinks.contact)
                Link("GitHub support", destination: SupportLinks.github)
                Link("Email support", destination: SupportLinks.email)
              }
              .multilineTextAlignment(.center).padding(28)
            }
            .preferredColorScheme(.dark)
            .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                          defaultFilename: "MovingSoon-recovery") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .alert("Saved checklist", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: { Text(message ?? "") }
        }
    }

}

struct StoreRecoveryCopy: Codable {
    let format: String
    let createdAt: Date
    let files: [String: Data]
}

/// Copies only the configured store and SQLite sidecars, never modifying them.
enum StoreRecoveryService {
    static let maximumSourceBytes = 100_000_000
    static func export(storeURL: URL) throws -> Data {
        var files: [String: Data] = [:]
        var total = 0
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: maximumSourceBytes - total + 1) ?? Data()
            total += data.count
            guard total <= maximumSourceBytes else { throw BackupError.tooLarge }
            files[url.lastPathComponent] = data
        }
        guard !files.isEmpty else { throw BackupError.invalid }
        return try JSONEncoder().encode(StoreRecoveryCopy(format: "app.movingsoon.store-recovery",
            createdAt: Date(), files: files))
    }
}
