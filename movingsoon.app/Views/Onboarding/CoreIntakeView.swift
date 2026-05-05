// CoreIntakeView.swift — The hyper-minimalist 2-step entry point
import SwiftUI
import SwiftData

struct CoreIntakeView: View {
    @Environment(\.modelContext) private var modelContext
    let onComplete: () -> Void
    
    @State private var anchorDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var destinationZip: String = ""
    @State private var originZip: String = ""
    
    var isValid: Bool {
        destinationZip.count == 5
    }
    
    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 40) {
                Spacer()
                
                Text("Let's get started.")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundColor(Theme.textPrimary)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("When are you moving?")
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
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Where are you moving from?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(2)
                    
                    TextField("Current ZIP (optional)", text: $originZip)
                        .keyboardType(.numberPad)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .padding()
                        .background(Theme.backgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .onChange(of: originZip) { _, newValue in
                            if newValue.count > 5 {
                                originZip = String(newValue.prefix(5))
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Where are you moving to?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(2)
                    
                    TextField("Enter destination ZIP", text: $destinationZip)
                        .keyboardType(.numberPad)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .padding()
                        .background(Theme.backgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        // Format validation
                        .onChange(of: destinationZip) { _, newValue in
                            if newValue.count > 5 {
                                destinationZip = String(newValue.prefix(5))
                            }
                        }
                }
                
                Spacer()
                
                Button(action: completeIntake) {
                    HStack {
                        Spacer()
                        Text("Continue")
                            .font(.system(size: 18, weight: .bold))
                        Image(systemName: "arrow.right")
                        Spacer()
                    }
                    .padding()
                    .background(isValid ? Theme.accentPrimary : Theme.backgroundElevated)
                    .foregroundColor(isValid ? .black : Theme.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!isValid)
                .animation(.easeInOut, value: isValid)
                .padding(.bottom, 20)
            }
            .padding(24)
        }
    }
    
    private func completeIntake() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let (state, city) = ZipBucketService.bucket(zip: destinationZip)
        
        // Generate a Move with the newly refactored minimal schema
        let move = Move(
            anchorDate: anchorDate,
            originZip: originZip.count == 5 ? originZip : nil,
            destinationZip: destinationZip,
            destinationStateBucket: state,
            destinationCityBucket: city
        )
        
        modelContext.insert(move)
        try? modelContext.save()
        
        withAnimation(.easeInOut(duration: 0.5)) {
            onComplete()
        }
    }
}
