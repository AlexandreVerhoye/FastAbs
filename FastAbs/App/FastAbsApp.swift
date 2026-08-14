import SwiftData
import SwiftUI

@main
struct FastAbsApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .tint(.fastCoral)
                .preferredColorScheme(appModel.appearance.colorScheme)
        }
        .modelContainer(for: WorkoutRecord.self)
    }
}

