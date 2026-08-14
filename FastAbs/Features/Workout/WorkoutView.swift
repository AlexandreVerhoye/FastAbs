import SwiftData
import SwiftUI

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("sound-enabled") private var soundEnabled = true
    @State private var session: WorkoutSession
    @State private var showsExitConfirmation = false
    @State private var didSave = false

    init(plan: WorkoutPlan) {
        _session = State(initialValue: WorkoutSession(plan: plan))
    }

    var body: some View {
        ZStack {
            LinearGradient.fastNight.ignoresSafeArea()

            if session.phase == .completed {
                CompletionView(plan: session.plan, onDone: { dismiss() })
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                workoutContent
            }

            if case let .preparing(count) = session.phase {
                preparationOverlay(count)
            }
        }
        .statusBarHidden()
        .interactiveDismissDisabled()
        .confirmationDialog("Arrêter la séance ?", isPresented: $showsExitConfirmation, titleVisibility: .visible) {
            Button("Quitter la séance", role: .destructive) {
                session.abandon()
                dismiss()
            }
            Button("Reprendre", role: .cancel) { session.resume() }
        } message: {
            Text("Votre progression sur cette séance ne sera pas enregistrée.")
        }
        .onAppear { session.start() }
        .onDisappear { session.stop() }
        .onChange(of: session.phase) { _, phase in
            if phase == .completed { saveCompletionOnce() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.handleAppBecameInactive() }
        }
    }

    private var workoutContent: some View {
        VStack(spacing: 14) {
            topBar
            motionStage
            nextStepCard
            playbackControls
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .foregroundStyle(.white)
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    session.pause()
                    showsExitConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .accessibilityLabel("Quitter la séance")

                Spacer()

                Text("ÉTAPE \(session.stepIndex + 1) SUR \(session.plan.steps.count)")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(.white.opacity(0.08), in: Capsule())

                Spacer()

                Button {
                    soundEnabled.toggle()
                } label: {
                    Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .foregroundStyle(soundEnabled ? Color.fastCoral : .white.opacity(0.55))
                .accessibilityLabel(soundEnabled ? "Désactiver les sons" : "Activer les sons")
            }

            ProgressView(value: session.totalProgress)
                .tint(.fastCoral)
                .background(.white.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var motionStage: some View {
        ZStack {
            ExerciseMotionView(
                motion: session.currentStep.motion,
                isPlaying: session.phase == .running,
                focusZones: session.currentStep.exercise?.zones ?? [.deepCore],
                accessibilityName: session.currentStep.exercise?.name
            )
            .id(session.currentStep.id)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.48),
                    .init(color: Color.fastNavy.opacity(0.42), location: 0.68),
                    .init(color: Color.fastNavy.opacity(0.96), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fastNavy.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) { zonePill.padding(16) }
        .overlay(alignment: .topTrailing) {
            CircularTimerRing(
                progress: session.stepProgress,
                seconds: Int(ceil(session.secondsRemaining)),
                color: session.currentStep.kind == .recovery ? .fastMint : .fastCoral,
                diameter: 64
            )
            .padding(14)
        }
        .overlay(alignment: .bottomLeading) { exerciseSummary.padding(20) }
        .layoutPriority(1)
        .accessibilityIdentifier("workout.motionStage")
    }

    @ViewBuilder
    private var zonePill: some View {
        if let zone = session.currentStep.exercise?.zones.first {
            Label(zone.title.uppercased(), systemImage: "scope")
                .foregroundStyle(zone.color)
                .workoutPill()
        } else {
            Label("RÉCUPÉRATION", systemImage: "wind")
                .foregroundStyle(Color.fastMint)
                .workoutPill()
        }
    }

    private var exerciseSummary: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(session.currentStep.title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .contentTransition(.opacity)
            Text(session.currentStep.exercise?.instruction ?? "Relâchez les épaules, inspirez lentement et préparez le mouvement suivant.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(3)
            if let breathing = session.currentStep.exercise?.breathing {
                Label(breathing, systemImage: "wind")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 300, alignment: .leading)
    }

    private var nextStepCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "forward.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.fastCoral)
                .frame(width: 34, height: 34)
                .background(Color.fastCoral.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("ENSUITE")
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.5))
                Text(session.nextStep?.title ?? "Séance terminée")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer()
            if let nextStep = session.nextStep {
                Text("\(nextStep.duration) s")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.54))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var playbackControls: some View {
        HStack(spacing: 14) {
            Button { session.togglePause() } label: {
                Label(
                    session.phase == .paused ? "Reprendre" : "Pause",
                    systemImage: session.phase == .paused ? "play.fill" : "pause.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .buttonStyle(.plain)
            .background(.white, in: Capsule())
            .foregroundStyle(Color.fastNavy)

            Button { session.skip() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.headline)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Passer à l’étape suivante")
        }
    }

    private func preparationOverlay(_ count: Int) -> some View {
        ZStack {
            Color.fastNavy.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("PRÉPAREZ-VOUS").font(.headline).foregroundStyle(.white.opacity(0.65))
                Text("\(count)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .id(count)
                Text(session.currentStep.title).font(.title2.bold()).foregroundStyle(Color.fastCoral)
            }
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Départ dans \(count) secondes. Premier exercice : \(session.currentStep.title)")
    }

    private func saveCompletionOnce() {
        guard !didSave else { return }
        didSave = true
        modelContext.insert(WorkoutRecord(plan: session.plan))
        try? modelContext.save()
    }
}

private struct CircularTimerRing: View {
    let progress: Double
    let seconds: Int
    let color: Color
    var diameter: CGFloat = 76

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0.001, 1 - progress))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.08), value: progress)
            Text("\(seconds)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(seconds) secondes restantes")
    }
}

private extension View {
    func workoutPill() -> some View {
        font(.caption2.weight(.heavy))
            .tracking(0.4)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
