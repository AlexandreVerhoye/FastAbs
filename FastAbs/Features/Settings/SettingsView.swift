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
                    LabeledContent("Durée", value: "\(appModel.preferences.durationMinutes) min")
                    LabeledContent("Difficulté", value: appModel.preferences.difficulty.title)
                    Button("Restaurer le programme recommandé") { appModel.restoreRecommendedPlan() }
                }

                Section("À propos") {
                    LabeledContent("Version", value: "1.0")
                    NavigationLink("Sécurité et mouvement") {
                        SafetyView()
                    }
                    Link("Code source de SevenAbs", destination: URL(string: "https://github.com/AlexandreVerhoye/SevenAbs")!)
                }
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
                notificationMessage = "Activez les notifications de FastAbs dans Réglages."
            } else {
                notificationMessage = "Un rappel discret sera envoyé chaque jour."
            }
        } else {
            NotificationScheduler.cancelReminder()
            notificationMessage = nil
        }
    }
}

private struct SafetyView: View {
    var body: some View {
        List {
            Label("Choisissez un niveau où le mouvement reste contrôlé.", systemImage: "checkmark.shield")
            Label("Arrêtez immédiatement en cas de douleur inhabituelle.", systemImage: "hand.raised.fill")
            Label("FastAbs ne remplace pas l’avis d’un professionnel de santé.", systemImage: "cross.case.fill")
        }
        .navigationTitle("Bouger en sécurité")
    }
}

