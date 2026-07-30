// EditMoveView.swift — Edit move details including ZIP and neighborhood
import SwiftUI
import SwiftData
import CoreLocation

struct EditMoveView: View {
    @Bindable var move: Move
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var anchorDate: Date
    @State private var showingResetConfirm = false
    @State private var showingAddServices = false

    // ZIP & Neighborhood edit state
    @State private var originZip: String
    @State private var destinationZip: String
    @State private var selectedOrigin: NeighborhoodResult?
    @State private var selectedDestination: NeighborhoodResult?

    @State private var originNeighborhoods: [NeighborhoodResult] = []
    @State private var destinationNeighborhoods: [NeighborhoodResult] = []
    @State private var isLoadingOrigin = false
    @State private var isLoadingDestination = false

    @State private var destGeocodeTask: Task<Void, Never>? = nil
    @State private var origGeocodeTask: Task<Void, Never>? = nil

    init(move: Move) {
        self.move = move
        self._anchorDate = State(initialValue: move.anchorDate)
        self._originZip = State(initialValue: move.originZip ?? "")
        self._destinationZip = State(initialValue: move.destinationZip)

        let originCoord = move.originLatitude != nil && move.originLongitude != nil
            ? CLLocationCoordinate2D(latitude: move.originLatitude!, longitude: move.originLongitude!)
            : nil
        let destCoord = move.destinationLatitude != nil && move.destinationLongitude != nil
            ? CLLocationCoordinate2D(latitude: move.destinationLatitude!, longitude: move.destinationLongitude!)
            : nil

        if let originNeighborhood = move.originNeighborhood {
            let name = originNeighborhood.components(separatedBy: ",").first ?? originNeighborhood
            self._selectedOrigin = State(initialValue: NeighborhoodResult(
                neighborhood: name.trimmingCharacters(in: .whitespaces),
                fullLabel: originNeighborhood,
                coordinate: originCoord
            ))
        } else {
            self._selectedOrigin = State(initialValue: nil)
        }

        if let destNeighborhood = move.destinationNeighborhood {
            let name = destNeighborhood.components(separatedBy: ",").first ?? destNeighborhood
            self._selectedDestination = State(initialValue: NeighborhoodResult(
                neighborhood: name.trimmingCharacters(in: .whitespaces),
                fullLabel: destNeighborhood,
                coordinate: destCoord
            ))
        } else {
            self._selectedDestination = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {

                        // MARK: Move Date
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Move Date")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(2)

                            DatePicker("", selection: $anchorDate, displayedComponents: .date)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .padding()
                                .background(Theme.backgroundElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // MARK: Starting Point (Origin)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Starting Point")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(2)

                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Origin ZIP")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    TextField("Optional", text: $originZip)
                                        .keyboardType(.numberPad)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: 120)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)

                                if isLoadingOrigin {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.textSecondary))
                                            .scaleEffect(0.8)
                                        Text("Finding neighborhoods…")
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textTertiary)
                                        Spacer()
                                    }
                                    .padding(.bottom, 14)
                                } else if !originNeighborhoods.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Select Neighborhood")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Theme.textTertiary)
                                            .textCase(.uppercase)
                                            .tracking(1)
                                            .padding(.horizontal, 16)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(originNeighborhoods) { hood in
                                                    let isSelected = selectedOrigin?.fullLabel == hood.fullLabel
                                                    Button {
                                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                        withAnimation(.spring(response: 0.3)) {
                                                            selectedOrigin = isSelected ? nil : hood
                                                        }
                                                    } label: {
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(hood.neighborhood)
                                                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                                                .foregroundColor(isSelected ? .black : Theme.textPrimary)
                                                            
                                                            let context = hood.fullLabel
                                                                .replacingOccurrences(of: hood.neighborhood + ", ", with: "")
                                                            if !context.isEmpty && context != hood.neighborhood {
                                                                Text(context)
                                                                    .font(.system(size: 10))
                                                                    .foregroundColor(isSelected ? .black.opacity(0.6) : Theme.textTertiary)
                                                            }
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(isSelected ? Theme.textSecondary : Theme.backgroundElevated)
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                    .padding(.bottom, 14)
                                } else if let label = selectedOrigin?.fullLabel {
                                    HStack {
                                        Spacer()
                                        Text(label)
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textTertiary)
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 14)
                                    }
                                }
                            }
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // MARK: New Home (Destination)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("New Home")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(2)

                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Destination ZIP")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    TextField("Required", text: $destinationZip)
                                        .keyboardType(.numberPad)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Theme.textPrimary)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: 120)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)

                                if isLoadingDestination {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.accentPrimary))
                                            .scaleEffect(0.8)
                                        Text("Finding neighborhoods…")
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textTertiary)
                                        Spacer()
                                    }
                                    .padding(.bottom, 14)
                                } else if !destinationNeighborhoods.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Select Neighborhood")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Theme.textTertiary)
                                            .textCase(.uppercase)
                                            .tracking(1)
                                            .padding(.horizontal, 16)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(destinationNeighborhoods) { hood in
                                                    let isSelected = selectedDestination?.fullLabel == hood.fullLabel
                                                    Button {
                                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                        withAnimation(.spring(response: 0.3)) {
                                                            selectedDestination = isSelected ? nil : hood
                                                        }
                                                    } label: {
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(hood.neighborhood)
                                                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                                                .foregroundColor(isSelected ? .black : Theme.textPrimary)
                                                            
                                                            let context = hood.fullLabel
                                                                .replacingOccurrences(of: hood.neighborhood + ", ", with: "")
                                                            if !context.isEmpty && context != hood.neighborhood {
                                                                Text(context)
                                                                    .font(.system(size: 10))
                                                                    .foregroundColor(isSelected ? .black.opacity(0.6) : Theme.textTertiary)
                                                            }
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(isSelected ? Theme.accentPrimary : Theme.backgroundElevated)
                                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                    .padding(.bottom, 14)
                                } else if let label = selectedDestination?.fullLabel {
                                    HStack {
                                        Spacer()
                                        Text(label)
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.textTertiary)
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 14)
                                    }
                                }
                            }
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // MARK: Info Rows
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Status")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(2)

                            VStack(spacing: 0) {
                                infoRow(label: "State", value: move.destinationStateBucket)
                                Divider().background(Theme.hairline)
                                infoRow(label: "Tasks", value: "\(move.completedCount) of \(move.totalCount) complete")
                            }
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // MARK: Add More Services (#8)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Customize")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(2)

                            Button {
                                showingAddServices = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add More Services")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.accentPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.accentPrimary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Theme.accentPrimary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text("Adds tasks for services you missed — won't remove anything you've already completed.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textTertiary)
                                .lineSpacing(2)
                        }

                        // MARK: About
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(2)

                            Link(destination: URL(string: "https://github.com/manidanesh/MovingSoon/blob/main/PRIVACY_POLICY.md")!) {
                                HStack {
                                    Text("Privacy Policy")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Theme.textTertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // MARK: Danger Zone
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Danger Zone")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.priorityCritical)
                                .textCase(.uppercase)
                                .tracking(2)

                            Button {
                                showingResetConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Start Over")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.priorityCritical)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.priorityCritical.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Theme.priorityCritical.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Text("Deletes all tasks and restarts the lifestyle interview. Your move date and ZIPs are kept.")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textTertiary)
                                .lineSpacing(2)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Edit Move")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        move.anchorDate = anchorDate
                        move.originZip = originZip.count == 5 ? originZip : nil
                        move.originNeighborhood = selectedOrigin?.fullLabel
                        move.originLatitude = selectedOrigin?.coordinate?.latitude
                        move.originLongitude = selectedOrigin?.coordinate?.longitude

                        move.destinationZip = destinationZip
                        move.destinationNeighborhood = selectedDestination?.fullLabel
                        move.destinationLatitude = selectedDestination?.coordinate?.latitude
                        move.destinationLongitude = selectedDestination?.coordinate?.longitude

                        let (state, city) = ZipBucketService.bucket(zip: destinationZip)
                        move.destinationStateBucket = state
                        move.destinationCityBucket = city

                        modelContext.saveOrLog()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.accentPrimary)
                    .disabled(destinationZip.count != 5)
                }
            }
            .confirmationDialog(
                "Start Over?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All Tasks & Restart", role: .destructive) {
                    resetMove()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all \(move.totalCount) tasks and your lifestyle profile. You'll redo the interview.")
            }
            .onChange(of: destinationZip) { _, newZip in
                fetchDestinationNeighborhoods(for: newZip)
            }
            .onChange(of: originZip) { _, newZip in
                fetchOriginNeighborhoods(for: newZip)
            }
            .sheet(isPresented: $showingAddServices) {
                AddMoreServicesView(move: move)
                    .preferredColorScheme(.dark)
            }
            .onAppear {
                if destinationZip.count == 5 {
                    isLoadingDestination = true
                    Task {
                        let results = await GeocoderService.neighborhoods(for: destinationZip)
                        await MainActor.run {
                            withAnimation {
                                destinationNeighborhoods = results
                                isLoadingDestination = false
                            }
                        }
                    }
                }
                if originZip.count == 5 {
                    isLoadingOrigin = true
                    Task {
                        let results = await GeocoderService.neighborhoods(for: originZip)
                        await MainActor.run {
                            withAnimation {
                                originNeighborhoods = results
                                isLoadingOrigin = false
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func fetchDestinationNeighborhoods(for zip: String) {
        destGeocodeTask?.cancel()
        guard zip.count == 5 else {
            destinationNeighborhoods = []
            selectedDestination = nil
            isLoadingDestination = false
            return
        }
        isLoadingDestination = true
        destGeocodeTask = Task {
            let results = await GeocoderService.neighborhoods(for: zip)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.4)) {
                    destinationNeighborhoods = results
                    if results.count == 1 {
                        selectedDestination = results.first
                    } else if let current = selectedDestination, !results.contains(where: { $0.fullLabel == current.fullLabel }) {
                        selectedDestination = nil
                    }
                    isLoadingDestination = false
                }
            }
        }
    }

    private func fetchOriginNeighborhoods(for zip: String) {
        origGeocodeTask?.cancel()
        guard zip.count == 5 else {
            originNeighborhoods = []
            selectedOrigin = nil
            isLoadingOrigin = false
            return
        }
        isLoadingOrigin = true
        origGeocodeTask = Task {
            let results = await GeocoderService.neighborhoods(for: zip)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.4)) {
                    originNeighborhoods = results
                    if results.count == 1 {
                        selectedOrigin = results.first
                    } else if let current = selectedOrigin, !results.contains(where: { $0.fullLabel == current.fullLabel }) {
                        selectedOrigin = nil
                    }
                    isLoadingOrigin = false
                }
            }
        }
    }

    private func resetMove() {
        // Delete all tasks
        for task in move.tasks {
            modelContext.delete(task)
        }
        move.tasks = []

        // Delete lifestyle profile — triggers re-interview on next launch
        if let profile = move.lifestyleProfile {
            modelContext.delete(profile)
        }
        move.lifestyleProfile = nil

        // Delete institutions
        for institution in move.institutions {
            modelContext.delete(institution)
        }
        move.institutions = []

        modelContext.saveOrLog()
        dismiss()
    }
}
