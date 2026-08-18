import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedTab: AppTab = .today
    @State private var showsWelcome = false

    var body: some View {
        // The modern tab API rather than `.tabItem` + `.tag`: the tab is one
        // declaration instead of a view wearing two modifiers that have to
        // agree, and it is what gives the bar its current behaviour on iOS —
        // including the sidebar it becomes on iPad and the search role.
        TabView(selection: $selectedTab) {
            Tab("Aujourd’hui", systemImage: "house.fill", value: AppTab.today) {
                TodayView()
            }

            Tab("Progression", systemImage: "chart.xyaxis.line", value: AppTab.progress) {
                NavigationStack { ProgressDashboardView() }
            }

            Tab("Mouvements", systemImage: "figure.mixed.cardio", value: AppTab.library) {
                ExerciseLibraryView()
            }

            Tab("Récompenses", systemImage: "medal.fill", value: AppTab.rewards) {
                NavigationStack { RewardsView() }
            }
        }
        // The tab bar was the one control in the app that changed what you
        // were looking at and said nothing on the wrist.
        .onChange(of: selectedTab) { _, _ in Haptics.selection() }
        .onAppear { showsWelcome = !appModel.hasSeenWelcome }
        .fullScreenCover(isPresented: $showsWelcome) {
            // What comes back is what the athlete described. Skipping hands
            // back the recommended settings rather than nothing, so the app is
            // configured either way.
            OnboardingView { preferences in
                appModel.previewTodayWorkout(for: preferences)
            } completion: { preferences in
                appModel.preferences = preferences
                appModel.hasSeenWelcome = true
                showsWelcome = false
            }
        }
    }
}

private enum AppTab: Hashable {
    case today, progress, library, rewards
}
