import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var selectedTab: AppTab = .today
    @State private var showsWelcome = false

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Aujourd’hui", systemImage: "house.fill") }
                .tag(AppTab.today)

            NavigationStack { ProgressDashboardView() }
                .tabItem { Label("Progression", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.progress)

            ExerciseLibraryView()
                .tabItem { Label("Mouvements", systemImage: "figure.mixed.cardio") }
                .tag(AppTab.library)

            NavigationStack { RewardsView() }
                .tabItem { Label("Récompenses", systemImage: "medal.fill") }
                .tag(AppTab.rewards)
        }
        // The tab bar was the one control in the app that changed what you
        // were looking at and said nothing on the wrist.
        .onChange(of: selectedTab) { _, _ in Haptics.selection() }
        .onAppear { showsWelcome = !appModel.hasSeenWelcome }
        .fullScreenCover(isPresented: $showsWelcome) {
            WelcomeView {
                appModel.hasSeenWelcome = true
                showsWelcome = false
            }
        }
    }
}

private enum AppTab: Hashable {
    case today, progress, library, rewards
}
