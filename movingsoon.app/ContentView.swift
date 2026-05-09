// ContentView.swift — Root router: onboarding → account setup → dashboard
import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var moves: [Move]
    @State private var phase: AppPhase = .loading

    enum AppPhase { case loading, onboarding, lifestyleInterview, dashboard }

    private var activeMove: Move? {
        moves.first { $0.phase == .active }
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            switch phase {
            case .loading:
                Color.clear.onAppear { resolvePhase() }

            case .onboarding:
                CoreIntakeView {
                    withAnimation(.easeInOut(duration: 0.4)) { phase = .lifestyleInterview }
                }
                .transition(.opacity)

            case .lifestyleInterview:
                if let move = activeMove {
                    LifestyleInterviewView(move: move) {
                        withAnimation(.easeInOut(duration: 0.4)) { phase = .dashboard }
                    }
                    .transition(.opacity)
                } else {
                    // Move not yet persisted — wait for it
                    Color.clear.onAppear { resolvePhase() }
                }

            case .dashboard:
                if let move = activeMove {
                    NavigationStack {
                        ZenDashboardView(move: move)
                            #if os(iOS)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(Theme.backgroundPrimary, for: .navigationBar)
                            .toolbarColorScheme(.dark, for: .navigationBar)
                            #endif
                    }
                    .transition(.opacity)
                }
            }
        }
        .onChange(of: moves.count) { _, _ in resolvePhase() }
        .onAppear { resolvePhase() }
        .preferredColorScheme(.dark)
    }

    private func resolvePhase() {
        if activeMove == nil {
            phase = .onboarding
        } else if activeMove?.lifestyleProfile == nil {
            phase = .lifestyleInterview
        } else {
            phase = .dashboard
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Move.self, ChecklistTask.self, VerificationEvent.self,
                               PendingSignal.self, FinancialInstitution.self], inMemory: true)
}
