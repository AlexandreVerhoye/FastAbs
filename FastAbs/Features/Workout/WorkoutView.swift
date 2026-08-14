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
    /// Held so the effort rating lands on this session's record rather than on
    /// whatever happens to be newest in the store.
    @State private var saved: WorkoutRecord?
    /// Shared by the countdown on every stage, so it travels between its corner
    /// and the middle of the screen instead of being replaced by another one.
    @Namespace private var timerSpace

    init(plan: WorkoutPlan) {
        _session = State(initialValue: WorkoutSession(plan: plan))
    }

    var body: some View {
        ZStack {
            LinearGradient.fastNight.ignoresSafeArea()

            if session.phase == .completed {
                CompletionView(
                    plan: session.plan,
                    activeSeconds: Int(session.activeSeconds.rounded()),
                    onRate: { record(effort: $0) },
                    onDone: { dismiss() }
                )
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
                saveAbandonedIfWorthKeeping()
                session.abandon()
                dismiss()
            }
            // Only picks the session back up if the app was the one that put it
            // down. Resuming unconditionally restarted a session the athlete
            // had paused on purpose.
            Button("Reprendre", role: .cancel) { session.resumeIfSystemPaused() }
        } message: {
            Text("Les séances de plus de trois minutes restent dans votre historique.")
        }
        .onAppear {
            Haptics.warmUp()
            session.start()
        }
        .onDisappear { session.stop() }
        .onChange(of: session.phase) { _, phase in
            if phase == .completed { saveCompletionOnce() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Only a real trip to the background. Reacting to every inactive
            // phase meant a notification banner paused the workout.
            if phase == .background { session.handleAppEnteredBackground() }
        }
    }

    private var workoutContent: some View {
        VStack(spacing: 14) {
            topBar
            motionStage
            // The recovery and transition screens already announce what is
            // coming; repeating it underneath was the clutter.
            if session.currentStep.kind == .exercise {
                nextStepCard
            }
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
                    Haptics.tap()
                    session.pause(bySystem: true)
                    showsExitConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.1), in: Circle())
                }
                .accessibilityLabel("Quitter la séance")

                Spacer()

                // Clamped: on the rest after the last movement there is no
                // seventh movement of six, and the counter said there was.
                Text("\(min(session.completedExerciseCount + 1, session.plan.exerciseCount)) SUR \(session.plan.exerciseCount)")
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(.white.opacity(0.08), in: Capsule())

                Spacer()

                Button {
                    Haptics.selection()
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

    @ViewBuilder
    private var motionStage: some View {
        ZStack {
            switch session.currentStep.kind {
            case .recovery: recoveryStage
            case .transition: transitionStage
            case .exercise: exerciseStage
            }
        }
        .animation(.smooth(duration: 0.55), value: session.currentStep.id)
    }

    /// Recovery is dead time on screen: an idle animation teaches nothing,
    /// while the seconds before a movement are the best moment to explain it.
    private var recoveryStage: some View {
        UpNextStage(
            eyebrow: "RÉCUPÉRATION",
            symbol: "wind",
            tint: .fastMint,
            caption: "Relâchez les épaules, respirez.",
            progress: session.stepProgress,
            seconds: Int(ceil(session.secondsRemaining)),
            next: session.nextExerciseStep,
            timerSpace: timerSpace
        )
        .accessibilityIdentifier("workout.recoveryStage")
    }

    /// Five seconds to change position. The same layout as recovery, because
    /// they answer the same question and switching between two different ones
    /// mid-session is what made the player feel like several apps.
    private var transitionStage: some View {
        UpNextStage(
            eyebrow: "EN PLACE",
            symbol: "figure.stand",
            tint: .fastCoral,
            caption: "Installez-vous.",
            progress: session.stepProgress,
            seconds: Int(ceil(session.secondsRemaining)),
            next: session.nextExerciseStep,
            timerSpace: timerSpace
        )
        .accessibilityIdentifier("workout.transitionStage")
    }

    private var exerciseStage: some View {
        ZStack {
            ExerciseMotionView(
                motion: session.currentStep.motion,
                isPlaying: session.phase == .running,
                focusZones: session.currentStep.exercise?.zones ?? [.deepCore],
                mirrored: session.currentStep.isMirrored,
                accessibilityName: session.currentStep.exercise?.name
            )
            .id(session.currentStep.id)
            .transition(.opacity.combined(with: .scale(scale: 1.04)))

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.44),
                    .init(color: Color.fastNavy.opacity(0.46), location: 0.64),
                    .init(color: Color.fastNavy.opacity(0.97), location: 1)
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
                color: .fastCoral,
                diameter: 64
            )
            .matchedGeometryEffect(id: "timer", in: timerSpace)
            .padding(14)
        }
        .overlay(alignment: .bottomLeading) { exerciseSummary.padding(20) }
        .layoutPriority(1)
        .accessibilityIdentifier("workout.motionStage")
    }

    @ViewBuilder
    private var zonePill: some View {
        HStack(spacing: 8) {
            if let pattern = session.currentStep.exercise?.pattern {
                Label(pattern.shortTitle.uppercased(), systemImage: pattern.symbol)
                    .foregroundStyle(pattern.color)
                    .workoutPill()
            }
            if let side = session.currentStep.side {
                Label(side.title.uppercased(), systemImage: "arrow.left.and.right")
                    .foregroundStyle(Color.fastOrange)
                    .workoutPill()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy, value: session.currentStep.id)
    }

    private var exerciseSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.currentStep.title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .contentTransition(.opacity)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            CoachingTicker(
                cues: session.currentStep.exercise.map(cues(for:)) ?? [],
                isPlaying: session.phase == .running
            )
            .id(session.currentStep.exercise?.id ?? "none")
        }
        .frame(maxWidth: 320, alignment: .leading)
    }

    /// What the coach says, in the order they would say it: the movement first,
    /// then the breath, then the details.
    private func cues(for exercise: Exercise) -> [String] {
        [exercise.instruction, exercise.breathing] + exercise.tips
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
                    session.phase.isPaused ? "Reprendre" : "Pause",
                    systemImage: session.phase.isPaused ? "play.fill" : "pause.fill"
                )
                .font(.headline)
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .buttonStyle(.plain)
            .background(.white, in: Capsule())
            .foregroundStyle(Color.fastNavy)

            Button {
                Haptics.tap()
                session.skip()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.headline)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Passer à l’étape suivante")
        }
        .animation(.snappy(duration: 0.22), value: session.phase)
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

    // MARK: - Recording

    private func saveCompletionOnce() {
        guard !didSave else { return }
        didSave = true
        let record = WorkoutRecord(
            plan: session.plan,
            activeDuration: Int(session.activeSeconds.rounded())
        )
        modelContext.insert(record)
        saved = record
        try? modelContext.save()
    }

    /// A session ended early is still training. Dropping it entirely made
    /// streaks lie about days the athlete had genuinely worked.
    private func saveAbandonedIfWorthKeeping() {
        guard !didSave else { return }
        let worked = Int(session.activeSeconds.rounded())
        guard worked >= WorkoutHistoryAnalytics.minimumActiveDuration else { return }
        didSave = true
        let record = WorkoutRecord(plan: session.plan, activeDuration: worked, wasCompleted: false)
        // Filed against what was actually attempted, so the completion ratio
        // reflects the session rather than the plan it was cut from.
        record.plannedDuration = worked
        record.exerciseIDs = Array(
            session.plan.movements.prefix(max(1, session.completedExerciseCount)).map(\.id)
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    private func record(effort: PerceivedEffort) {
        guard let saved else { return }
        saved.perceivedEffortRaw = effort.rawValue
        try? modelContext.save()
    }
}

/// The screen between two movements — recovery or a change of position.
///
/// One layout for both, because they answer the same question: how long have I
/// got, and what is it for. The countdown sits in the middle at full size and
/// carries the same identity as the small ring on the exercise stage, so it
/// travels there and back rather than one being swapped for the other.
struct UpNextStage: View {
    let eyebrow: String
    let symbol: String
    let tint: Color
    let caption: String
    let progress: Double
    let seconds: Int
    let next: WorkoutStep?
    let timerSpace: Namespace.ID

    var body: some View {
        VStack(spacing: 0) {
            Label(eyebrow, systemImage: symbol)
                .font(.caption2.weight(.heavy))
                .tracking(0.8)
                .foregroundStyle(tint)
                .padding(.top, 22)

            Spacer(minLength: 8)

            CircularTimerRing(
                progress: progress,
                seconds: seconds,
                color: tint,
                diameter: 132,
                lineWidth: 12
            )
            .matchedGeometryEffect(id: "timer", in: timerSpace)

            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .padding(.top, 12)

            Spacer(minLength: 8)

            if let next, let exercise = next.exercise {
                NextExerciseBriefing(exercise: exercise, side: next.side, duration: next.duration)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text("Dernier effort, la séance se termine juste après.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fastNavy.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .layoutPriority(1)
    }
}

/// What is coming next, while the athlete catches their breath.
///
/// A card rather than a paragraph: the movement plays in it at the size it will
/// be performed at, the side is stated when there is one, and the one mistake
/// worth naming sits underneath. Out of breath with a few seconds to read, that
/// is the whole budget.
struct NextExerciseBriefing: View {
    let exercise: Exercise
    var side: BodySide?
    let duration: Int

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ExerciseMotionView(
                motion: exercise.motion,
                isPlaying: true,
                focusZones: exercise.zones,
                mirrored: side == .right
            )
            .frame(width: 96, height: 96)
            .background(
                LinearGradient(
                    colors: [exercise.pattern.color.opacity(0.22), .white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text("ENSUITE")
                        .font(.caption2.weight(.heavy))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.45))
                    Text("\(duration) S")
                        .font(.caption2.weight(.heavy).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                    if let side {
                        Text(side.title.uppercased())
                            .font(.caption2.weight(.heavy))
                            .tracking(0.7)
                            .padding(.horizontal, 7)
                            .frame(height: 18)
                            .background(Color.fastOrange.opacity(0.22), in: Capsule())
                            .foregroundStyle(Color.fastOrange)
                    }
                }

                Text(exercise.name)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Label(exercise.mistake, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.fastOrange.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Prochain exercice : \(exercise.name)\(side.map { ", côté \($0.title)" } ?? ""), "
                + "\(duration) secondes. \(exercise.setup) À éviter : \(exercise.mistake)"
        )
    }
}

/// Coaching cues, one at a time.
///
/// Four cues shown at once and all truncated is four things nobody reads. One
/// at a time, held long enough to finish, is the same information delivered at
/// the speed someone mid-plank can take it.
struct CoachingTicker: View {
    let cues: [String]
    var isPlaying: Bool
    var interval: Double = 4.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    private var current: String { cues.isEmpty ? "" : cues[index % cues.count] }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Reserves the tallest line so the layout underneath never jumps
            // between cues.
            Text(cues.max(by: { $0.count < $1.count }) ?? "")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()

            Text(current)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .id(index)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                )
        }
        .clipped()
        .animation(.smooth(duration: 0.45), value: index)
        .task(id: cues.count) { await run() }
        .accessibilityLabel(cues.joined(separator: ". "))
    }

    private func run() async {
        guard cues.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled, isPlaying else { continue }
            index += 1
        }
    }
}

struct CircularTimerRing: View {
    let progress: Double
    let seconds: Int
    let color: Color
    var diameter: CGFloat = 76
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, 1 - progress))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.08), value: progress)
            Text("\(seconds)")
                .font(.system(size: diameter * 0.34, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText(countsDown: true))
                .foregroundStyle(.white)
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
