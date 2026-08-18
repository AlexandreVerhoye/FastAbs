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
    /// What the last change to the trained areas did to the rest of the
    /// settings, so an adjustment made on the athlete's behalf is visible rather
    /// than discovered later in a session that looks wrong.
    @State private var areaNote: String?

    /// The chosen zones, or what is being trained when none was named.
    private var focusSummary: String {
        let zones = appModel.preferences.explicitFocus
        return zones.isEmpty
            ? BodyArea.describe(appModel.preferences.trainedAreas)
            : zones.map(\.shortTitle).sorted().joined(separator: " · ")
    }

    /// The movements the engine may draw from with the current areas switched
    /// on — the number that actually changes when a switch is flipped.
    private var availableMovementCount: Int {
        let areas = appModel.preferences.trainedAreas
        return ExerciseCatalog.all.count { $0.areas.isSubset(of: areas) }
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

                // The one training decision that belongs in Settings rather
                // than in the customisation sheet: everything in that sheet is
                // about today's session, and this is about what the athlete
                // trains at all. Durable scope here, today's session there —
                // one editor each, which is what stops the two screens from
                // disagreeing.
                Section {
                    ForEach(BodyArea.allCases) { area in
                        AreaToggle(
                            area: area,
                            isOn: appModel.preferences.trainedAreas.contains(area),
                            isLocked: isOnlyArea(area),
                            movementCount: ExerciseCatalog.all.count { $0.areas.contains(area) }
                        ) { enabled in
                            toggle(area, enabled: enabled)
                        }
                    }
                } header: {
                    Text("Zones du corps")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Le coach ne programme que des mouvements dont toutes les zones sont activées. \(availableMovementCount) mouvements disponibles.")
                        if let areaNote {
                            Label(areaNote, systemImage: "wand.and.stars")
                                .foregroundStyle(Color.haraCoral)
                                .transition(.opacity)
                        }
                        Text("Tout se fait sans matériel, avec un tapis.")
                            .foregroundStyle(.tertiary)
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

    /// True when this is the last area standing. Training nothing is not a
    /// training preference, so the switch is disabled rather than being allowed
    /// to fail — a control that refuses a tap teaches nothing.
    private func isOnlyArea(_ area: BodyArea) -> Bool {
        appModel.preferences.trainedAreas == [area]
    }

    private func toggle(_ area: BodyArea, enabled: Bool) {
        let focusBefore = appModel.preferences.explicitFocus
        guard appModel.setArea(area, enabled: enabled) else {
            Haptics.warning()
            return
        }
        Haptics.selection()

        let focusAfter = appModel.preferences.explicitFocus
        let dropped = focusBefore.subtracting(focusAfter)
        withAnimation(.snappy) {
            if !dropped.isEmpty {
                let names = dropped.map(\.shortTitle).sorted().joined(separator: " · ")
                areaNote = focusAfter.isEmpty
                    ? "Priorité « \(names) » retirée : le reste de vos réglages est inchangé."
                    : "Priorité « \(names) » retirée, les autres sont gardées."
            } else {
                areaNote = enabled
                    ? "\(area.title) ajouté au programme du jour."
                    : "\(area.title) retiré. Le reste de vos réglages est inchangé."
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

/// One part of the body, with what it covers and how much of the catalog it
/// unlocks.
private struct AreaToggle: View {
    let area: BodyArea
    let isOn: Bool
    let isLocked: Bool
    let movementCount: Int
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(
            isOn: Binding(get: { isOn }, set: onChange)
        ) {
            HStack(spacing: 12) {
                Image(systemName: area.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(area.color)
                    .frame(width: 32, height: 32)
                    .background(area.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(area.title).font(.subheadline.weight(.semibold))
                    Text(area.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(movementCount) mouvements")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .tint(area.color)
        .disabled(isLocked)
        .accessibilityHint(isLocked ? "Au moins une zone doit rester activée." : "")
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

