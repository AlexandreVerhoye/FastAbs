import SwiftData
import SwiftUI

@main
struct HaraApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .tint(.haraCoral)
                .preferredColorScheme(appModel.appearance.colorScheme)
        }
        .modelContainer(for: WorkoutRecord.self)
    }
}

