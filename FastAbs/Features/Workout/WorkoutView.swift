import SwiftData
import SwiftUI

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
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
        VStack(spacing: 0) {
            topBar
            ProgressView(value: session.totalProgress)
                .tint(.fastCoral)
                .padding(.horizontal, 20)
                .padding(.top, 6)

            VStack(spacing: 16) {
                exerciseHeader
                motionStage
                timerAndControls
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .foregroundStyle(.white)
    }

    private var topBar: some View {
        HStack {
            Button {
                session.pause()
                showsExitConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("Quitter la séance")
            Spacer()
            Text("\(session.stepIndex + 1) / \(session.plan.steps.count)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Image(systemName: session.currentStep.kind == .recovery ? "heart.fill" : "figure.core.training")
                .frame(width: 44, height: 44)
                .foregroundStyle(session.currentStep.kind == .recovery ? Color.fastMint : Color.fastCoral)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var exerciseHeader: some View {
        VStack(spacing: 8) {
            if let zone = session.currentStep.exercise?.zones.first {
                Text(zone.title.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(zone.color)
            } else {
                Text("RESPIRER").font(.caption.weight(.heavy)).foregroundStyle(Color.fastMint)
            }
            Text(session.currentStep.title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
            Text(session.currentStep.exercise?.instruction ?? "Relâchez les épaules, inspirez lentement et préparez le mouvement suivant.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(minHeight: 54)
        }
    }

    private var motionStage: some View {
        ExerciseMotionView(
            motion: session.currentStep.motion,
            isPlaying: session.phase == .running,
            highlightedZones: session.currentStep.exercise?.zones ?? [.deepCore]
        )
        .id(session.currentStep.id)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Label("3D native", systemImage: "view.3d")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
                .padding(12)
        }
        .layoutPriority(1)
    }

    private var timerAndControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                CircularTimerRing(
                    progress: session.stepProgress,
                    seconds: Int(ceil(session.secondsRemaining)),
                    color: session.currentStep.kind == .recovery ? .fastMint : .fastCoral
                )
                VStack(alignment: .leading, spacing: 5) {
                    Text("Ensuite").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.55))
                    Text(session.nextStep?.title ?? "Séance terminée")
                        .font(.headline)
                    if let breathing = session.currentStep.exercise?.breathing {
                        Label(breathing, systemImage: "wind")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(2)
                    }
                }
                Spacer()
            }

            HStack(spacing: 14) {
                Button { session.togglePause() } label: {
                    Label(session.phase == .paused ? "Reprendre" : "Pause", systemImage: session.phase == .paused ? "play.fill" : "pause.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.plain)
                .background(.white, in: Capsule())
                .foregroundStyle(Color.fastNavy)

                Button { session.skip() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.headline)
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Passer à l’étape suivante")
            }
        }
        .padding(.top, 2)
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
        .frame(width: 76, height: 76)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(seconds) secondes restantes")
    }
}
