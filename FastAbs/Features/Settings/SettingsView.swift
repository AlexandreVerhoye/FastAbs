import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("sound-enabled") private var soundEnabled = true
    @AppStorage("haptics-enabled") private var hapticsEnabled = true
    @AppStorage("reminder-enabled") private var reminderEnabled = false
    @AppStorage("reminder-hour") private var reminderHour = 8
    @State private var reminderDate = Calendar.current.date(from: DateComponents(hour: 8)) ?? .now
    @State private var notificationMessage: String?

    @Environment(\.modelContext) private var modelContext
    @Query private var records: [WorkoutRecord]
    @State private var showsEraseConfirmation = false

    var body: some View {
        @Bindable var appModel = appModel
        NavigationStack {
            Form {
                Section("Expérience") {
                    Toggle("Sons de séance", isOn: $soundEnabled)
                    Toggle("Retours haptiques", isOn: $hapticsEnabled)
                    Picker("Apparence", selection: $appModel.appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section("Rappel quotidien") {
                    Toggle("Me rappeler de bouger", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { _, enabled in
                            Task { await configureReminder(enabled: enabled) }
                        }
                    if reminderEnabled {
                        DatePicker("Heure", selection: $reminderDate, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderDate) { _, value in
                                reminderHour = Calendar.current.component(.hour, from: value)
                                Task { await configureReminder(enabled: true) }
                            }
                    }
                    if let notificationMessage {
                        Text(notificationMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Programme") {
                    // Read-only rows told you what you had already chosen and
                    // gave you no way to change it. They are controls now.
                    Stepper(
                        "Durée : \(appModel.preferences.durationMinutes) min",
                        value: Binding(
                            get: { appModel.preferences.durationMinutes },
                            set: { appModel.preferences.durationMinutes = $0 }
                        ),
                        in: 5...20
                    )
                    Picker(
                        "Difficulté",
                        selection: Binding(
                            get: { appModel.preferences.difficulty },
                            set: { appModel.preferences.difficulty = $0 }
                        )
                    ) {
                        ForEach(WorkoutDifficulty.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    Toggle(
                        "Sans sauts",
                        isOn: Binding(
                            get: { appModel.preferences.apartmentFriendly },
                            set: { appModel.preferences.apartmentFriendly = $0 }
                        )
                    )
                    Toggle(
                        "Préserver la nuque",
                        isOn: Binding(
                            get: { appModel.preferences.neckFriendly },
                            set: { appModel.preferences.neckFriendly = $0 }
                        )
                    )
                    Button("Restaurer le programme recommandé") { appModel.restoreRecommendedPlan() }
                }

                Section("À propos") {
                    LabeledContent("Version", value: "1.0")
                    NavigationLink("Sécurité et mouvement") {
                        SafetyView()
                    }
                }

                Section {
                    Button("Effacer mes données", role: .destructive) {
                        showsEraseConfirmation = true
                    }
                } header: {
                    Text("Données")
                } footer: {
                    Text("Supprime l’historique des séances, les badges et les défis. Vos réglages sont conservés.")
                }
            }
            .confirmationDialog(
                "Effacer toutes vos données ?",
                isPresented: $showsEraseConfirmation,
                titleVisibility: .visible
            ) {
                Button("Tout effacer", role: .destructive) { eraseHistory() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("\(records.count) séance\(records.count == 1 ? "" : "s") seront définitivement supprimées. Cette action est irréversible.")
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }.fontWeight(.semibold)
                }
            }
            .onAppear {
                reminderDate = Calendar.current.date(from: DateComponents(hour: reminderHour)) ?? .now
            }
        }
    }

    @MainActor
    private func configureReminder(enabled: Bool) async {
        if enabled {
            let granted = await NotificationScheduler.requestAndSchedule(hour: reminderHour)
            if !granted {
                reminderEnabled = false
                notificationMessage = "Activez les notifications de Hara dans Réglages."
            } else {
                notificationMessage = "Un rappel discret sera envoyé chaque jour."
            }
        } else {
            NotificationScheduler.cancelReminder()
            notificationMessage = nil
        }
    }

    /// Removes every stored workout. Badges, streaks and challenges are all
    /// derived from these records, so deleting them clears the lot.
    private func eraseHistory() {
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }

}

private struct SafetyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [WorkoutRecord]
    @State private var showsEraseConfirmation = false

    var body: some View {
        List {
            Label("Choisissez un niveau où le mouvement reste contrôlé.", systemImage: "checkmark.shield")
            Label("Arrêtez immédiatement en cas de douleur inhabituelle.", systemImage: "hand.raised.fill")
            Label("Hara ne remplace pas l’avis d’un professionnel de santé.", systemImage: "cross.case.fill")
        }
        .navigationTitle("Bouger en sécurité")
    }

}

