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

    /// The chosen zones, or the whole wall when none was named.
    private var focusSummary: String {
        let zones = appModel.preferences.focusZones.filter { $0 != .fullCore }
        return zones.isEmpty
            ? MuscleZone.fullCore.title
            : zones.map(\.shortTitle).sorted().joined(separator: " · ")
    }

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

                // Shown, not edited. Every one of these had a control here and
                // a second control in the customisation sheet, and the two did
                // not behave alike — the sheet writes through live and then
                // starts the session, this one only wrote the preference. Two
                // editors for one setting is how an app stops agreeing with
                // itself, so the sheet keeps the job and this reports it.
                Section("Programme") {
                    LabeledContent("Durée", value: "\(appModel.preferences.durationMinutes) min")
                    LabeledContent("Difficulté", value: appModel.preferences.difficulty.title)
                    LabeledContent("Rythme") {
                        Text(appModel.preferences.difficulty.cadenceDescription)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    LabeledContent("Priorité", value: focusSummary)
                    if !appModel.preferences.excludedExerciseIDs.isEmpty {
                        LabeledContent(
                            "Mouvements écartés",
                            value: "\(appModel.preferences.excludedExerciseIDs.count)"
                        )
                    }
                    LabeledContent("Coach adaptatif", value: appModel.preferences.adaptiveCoaching ? "Activé" : "Désactivé")
                    Text("Réglez tout cela depuis « Personnaliser », sur l’écran d’accueil.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Restaurer le programme recommandé") {
                        Haptics.tap()
                        appModel.restoreRecommendedPlan()
                    }
                }

                Section("À propos") {
                    LabeledContent("Version", value: Bundle.main.versionSummary)
                    NavigationLink("Sécurité et mouvement") {
                        SafetyView()
                    }
                }

                Section {
                    Button("Effacer mes données", role: .destructive) {
                        Haptics.warning()
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
                Button("Tout effacer", role: .destructive) {
                    Haptics.halt()
                    eraseHistory()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("\(records.count) séance\(records.count == 1 ? "" : "s") seront définitivement supprimées. Cette action est irréversible.")
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        Haptics.tap()
                        dismiss()
                    }
                    .fontWeight(.semibold)
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

