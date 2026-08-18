import SwiftData
import SwiftUI

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("sound-enabled") private var soundEnabled = true
    @State private var session: WorkoutSession
    @State private var showsExitConfirmation = false
    @State private var didSave = false
    /// Held so the effort rating lands on this session's record rather than on
    /// whatever happens to be newest in the store.
    @State private var saved: WorkoutRecord?

    init(plan: WorkoutPlan) {
        _session = State(initialValue: WorkoutSession(plan: plan))
    }

    var body: some View {
        ZStack {
            LinearGradient.haraNight.ignoresSafeArea()

            if session.phase == .completed {
                CompletionView(
                    plan: session.plan,
                    activeSeconds: Int(session.activeSeconds.rounded()),
                    onRate: { record(effort: $0) },
                    onDone: { dismiss() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(1)
            } else {
                workoutContent
            }

            if session.isPreparing {
                SessionPreview(
                    plan: session.plan,
                    secondsRemaining: session.leadInRemaining,
                    progress: session.leadInProgress,
                    isPaused: session.phase.isPaused,
                    onBegin: {
                        Haptics.tap()
                        session.beginNow()
                    },
                    onClose: { confirmExit() }
                )
                .transition(.opacity)
                .zIndex(2)
            }
        }
        // Both of these used to pop into place. The phase changes inside the
        // session, and nothing on this side ever opened a transaction for it,
        // so the transitions declared above had nothing to run inside.
        .animation(stageMotion, value: session.phase == .completed)
        .animation(stageMotion, value: session.isPreparing)
        .statusBarHidden()
        .interactiveDismissDisabled()
        // An alert rather than a confirmation dialog. A dialog anchors itself to
        // whatever presented it, and this one is raised from two different
        // places — the player's close button and the lead-in's — so it had no
        // single anchor to find and drew itself mid-screen with its tail
        // pointing at nothing. A destructive decision with two answers is what
        // an alert is for anyway.
        .alert("Arrêter la séance ?", isPresented: $showsExitConfirmation) {
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
        .onAppear { session.start() }
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

    /// One curve for every change of step, so the countdown travelling to the
    /// corner, the stage crossfading and the cards below all move together.
    private var stageMotion: Animation? {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.52, dampingFraction: 0.88)
    }

    private var workoutContent: some View {
        VStack(spacing: 14) {
            topBar
            motionStage
            // The recovery and transition screens already announce what is
            // coming; repeating it underneath was the clutter.
            if session.currentStep.kind == .exercise {
                nextStepCard
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            playbackControls
        }
        .animation(stageMotion, value: session.currentStep.kind)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .foregroundStyle(.white)
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button { confirmExit() } label: {
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
                    .contentTransition(.numericText())

                Spacer()

                Button {
                    Haptics.selection()
                    soundEnabled.toggle()
                } label: {
                    Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.1), in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .foregroundStyle(soundEnabled ? Color.haraCoral : .white.opacity(0.55))
                .accessibilityLabel(soundEnabled ? "Désactiver les sons" : "Activer les sons")
            }

            ProgressView(value: session.totalProgress)
                .tint(.haraCoral)
                .background(.white.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    // MARK: - The stage

    /// The card the session is watched on.
    ///
    /// One container for all three kinds of step, with the countdown drawn on
    /// top of it rather than inside either layout. That is what lets the ring
    /// travel between the corner of a movement and the middle of a rest instead
    /// of one being swapped for the other — the previous attempt paired two
    /// `matchedGeometryEffect` sources across two branches of a `switch`, which
    /// SwiftUI resolves by picking one and dropping the animation.
    private var motionStage: some View {
        GeometryReader { proxy in
            let isWorking = session.currentStep.kind == .exercise
            let placement = isWorking
                ? TimerPlacement.working(in: proxy.size)
                : TimerPlacement.waiting(in: proxy.size)

            ZStack {
                stageContent(reserving: placement.reservedHeight)

                CircularTimerRing(
                    progress: session.stepProgress,
                    seconds: Int(ceil(session.secondsRemaining)),
                    color: stageTint,
                    diameter: placement.diameter,
                    lineWidth: placement.lineWidth
                )
                .position(placement.centre)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.haraNavy.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: Metric.Radius.hero, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Metric.Radius.hero, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .animation(stageMotion, value: session.currentStep.id)
        }
        .layoutPriority(1)
        .accessibilityIdentifier("workout.motionStage")
    }

    @ViewBuilder
    private func stageContent(reserving reserved: CGFloat) -> some View {
        switch session.currentStep.kind {
        case .exercise:
            exerciseStage.transition(.opacity)
        case .recovery, .transition:
            // Deliberately one branch for both. They answer the same question,
            // and giving them separate branches made SwiftUI tear the whole
            // card down to swap two labels.
            upNextStage(reserving: reserved).transition(.opacity)
        }
    }

    private var stageTint: Color {
        switch session.currentStep.kind {
        case .exercise: .haraCoral
        case .recovery: .haraMint
        case .transition: session.nextIsSideSwitch ? .haraOrange : .haraCoral
        }
    }

    /// Recovery, and the five seconds set aside to change position.
    ///
    /// Recovery is dead time on screen: an idle animation teaches nothing,
    /// while the seconds before a movement are the best moment to explain it.
    private func upNextStage(reserving reserved: CGFloat) -> some View {
        let isChangingSides = session.currentStep.kind == .transition && session.nextIsSideSwitch
        return UpNextStage(
            eyebrow: eyebrow(changingSides: isChangingSides),
            symbol: symbol(changingSides: isChangingSides),
            tint: stageTint,
            caption: caption(changingSides: isChangingSides),
            reservedHeight: reserved,
            next: session.nextExerciseStep,
            arrivingSide: isChangingSides ? session.nextExerciseStep?.side : nil
        )
        .accessibilityIdentifier(
            session.currentStep.kind == .recovery
                ? "workout.recoveryStage"
                : "workout.transitionStage"
        )
    }

    private func eyebrow(changingSides: Bool) -> String {
        if changingSides { return "CHANGEZ DE CÔTÉ" }
        return session.currentStep.kind == .recovery ? "RÉCUPÉRATION" : "EN PLACE"
    }

    private func symbol(changingSides: Bool) -> String {
        if changingSides { return "arrow.left.arrow.right" }
        return session.currentStep.kind == .recovery ? "wind" : "figure.stand"
    }

    private func caption(changingSides: Bool) -> String {
        if changingSides { return "Basculez sur l’autre côté." }
        return session.currentStep.kind == .recovery
            ? "Relâchez les épaules, respirez."
            : "Installez-vous."
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
                    .init(color: Color.haraNavy.opacity(0.46), location: 0.64),
                    .init(color: Color.haraNavy.opacity(0.97), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) { patternPill.padding(16) }
        .overlay(alignment: .bottomLeading) { exerciseSummary.padding(20) }
    }

    @ViewBuilder
    private var patternPill: some View {
        if let pattern = session.currentStep.exercise?.pattern {
            Label(pattern.shortTitle.uppercased(), systemImage: pattern.symbol)
                .foregroundStyle(pattern.color)
                .workoutPill()
        }
    }

    private var exerciseSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let side = session.currentStep.side {
                SideIndicator(side: side, scale: .compact, announcesArrival: session.isSideSwitch)
                    .frame(maxWidth: 268)
            }

            // The step's own title appends the side, which the indicator above
            // now states far more clearly than a suffix ever did.
            Text(session.currentStep.exercise?.name ?? session.currentStep.title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            CoachingTicker(
                cues: session.currentStep.exercise.map(cues(for:)) ?? [],
                isPlaying: session.phase == .running
            )
            .id(session.currentStep.exercise?.id ?? "none")
        }
        .frame(maxWidth: 340, alignment: .leading)
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
                .foregroundStyle(Color.haraCoral)
                .frame(width: 34, height: 34)
                .background(Color.haraCoral.opacity(0.14), in: Circle())
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
            .buttonStyle(.card)
            .background(.white, in: Capsule())
            .foregroundStyle(Color.haraNavy)

            Button {
                Haptics.tap()
                session.skip()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.headline)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.card)
            .accessibilityLabel("Passer à l’étape suivante")
        }
        .animation(.snappy(duration: 0.22), value: session.phase)
    }

    private func confirmExit() {
        Haptics.tap()
        session.pause(bySystem: true)
        showsExitConfirmation = true
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
        record.plannedActiveDuration = worked
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

/// Where the countdown sits, and how big, on each kind of screen.
///
/// Computed rather than laid out. The only way SwiftUI will move a view instead
/// of replacing it is if its centre and its frame are values it can
/// interpolate, so both are stated here and the rest screen reserves exactly
/// `reservedHeight` at the top — which means its caption can never end up
/// underneath the ring, at any type size.
struct TimerPlacement {
    let diameter: CGFloat
    let centre: CGPoint

    /// Out of the way, in the corner: the figure is what matters mid-movement.
    static func working(in size: CGSize) -> TimerPlacement {
        let diameter: CGFloat = 66
        return TimerPlacement(
            diameter: diameter,
            centre: CGPoint(x: size.width - 16 - diameter / 2, y: 16 + diameter / 2)
        )
    }

    /// Front and centre: on a rest the countdown is the whole point, and it has
    /// to be readable from the floor.
    static func waiting(in size: CGSize) -> TimerPlacement {
        let diameter = min(156, max(112, size.width * 0.40))
        return TimerPlacement(
            diameter: diameter,
            centre: CGPoint(x: size.width / 2, y: max(diameter / 2 + 66, size.height * 0.30))
        )
    }

    var lineWidth: CGFloat { max(7, diameter * 0.085) }
    var reservedHeight: CGFloat { centre.y + diameter / 2 + 16 }
}

/// Which side of the body the movement is on.
///
/// This used to be a chip in the corner next to the pattern label, which put
/// the single piece of information you cannot recover by looking at the figure
/// — the figure is mirrored, and mirrored looks like the same picture — at the
/// same weight as a taxonomy label. Here both sides are always drawn and one of
/// them is lit, so the answer is a position rather than a word to read, and a
/// change of side is something that visibly crosses over.
struct SideIndicator: View {
    enum Scale {
        case compact, prominent

        var height: CGFloat { self == .compact ? 34 : 44 }
        var font: Font {
            self == .compact
                ? .caption.weight(.heavy)
                : .subheadline.weight(.heavy)
        }
    }

    let side: BodySide
    var scale: Scale = .prominent
    /// Enters on the other side and crosses over. A change of side is worth
    /// watching happen; arriving already changed is how it gets missed.
    var announcesArrival = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit: BodySide?
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 4) {
            half(.left)
            half(.right)
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.14), lineWidth: 1) }
        .onAppear {
            guard announcesArrival, !reduceMotion else {
                lit = side
                return
            }
            lit = side == .left ? .right : .left
            Task {
                try? await Task.sleep(for: .milliseconds(340))
                withAnimation(.spring(response: 0.52, dampingFraction: 0.72)) { lit = side }
            }
        }
        .onChange(of: side) { _, updated in
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.74)) {
                lit = updated
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Côté \(side.title.lowercased())")
    }

    private func half(_ candidate: BodySide) -> some View {
        let isLit = (lit ?? side) == candidate
        return HStack(spacing: 6) {
            if candidate == .left {
                Image(systemName: "arrow.left").font(.caption2.weight(.black))
            }
            Text(candidate.title.uppercased())
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if candidate == .right {
                Image(systemName: "arrow.right").font(.caption2.weight(.black))
            }
        }
        .font(scale.font)
        .foregroundStyle(isLit ? Color.white : .white.opacity(0.38))
        .frame(maxWidth: .infinity)
        .frame(height: scale.height)
        .background {
            if isLit {
                Capsule()
                    .fill(LinearGradient.haraHero)
                    .matchedGeometryEffect(id: "sideHighlight", in: highlight)
                    .shadow(color: .haraCoral.opacity(0.45), radius: 10, y: 3)
            }
        }
    }
}

/// The screen between two movements — recovery or a change of position.
///
/// One layout for both, because they answer the same question: how long have I
/// got, and what is it for. The countdown itself is drawn by the stage above
/// this; the space it occupies is reserved here.
struct UpNextStage: View {
    let eyebrow: String
    let symbol: String
    let tint: Color
    let caption: String
    let reservedHeight: CGFloat
    let next: WorkoutStep?
    /// Set only when this pause exists to change sides.
    var arrivingSide: BodySide?

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: reservedHeight)

            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.64))
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .padding(.horizontal, 20)

            if let arrivingSide {
                SideIndicator(side: arrivingSide, announcesArrival: true)
                    .frame(maxWidth: 300)
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
            }

            Spacer(minLength: 10)

            if let next, let exercise = next.exercise {
                NextExerciseBriefing(exercise: exercise, side: next.side, duration: next.duration)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            } else {
                Text("Dernier effort, la séance se termine juste après.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            Label(eyebrow, systemImage: symbol)
                .font(.caption2.weight(.heavy))
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(tint)
                .contentTransition(.opacity)
                .padding(.horizontal, 20)
                .padding(.top, 20)
        }
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
                            .background(Color.haraOrange.opacity(0.22), in: Capsule())
                            .foregroundStyle(Color.haraOrange)
                    }
                }

                Text(exercise.name)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Label(exercise.mistake, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.haraOrange.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Metric.Radius.card, style: .continuous))
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
    /// A mirror of `isPlaying`, because the loop below reads it long after the
    /// view value it was captured from has been replaced. `@State` is read
    /// through storage and stays current; a plain property is frozen at the
    /// moment the task started, which is why the cues kept turning over
    /// throughout a pause.
    @State private var isRunning = true

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
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                )
        }
        .clipped()
        .animation(.smooth(duration: 0.45), value: index)
        .task(id: cues.first) { await run() }
        .onAppear { isRunning = isPlaying }
        .onChange(of: isPlaying) { _, playing in isRunning = playing }
        .accessibilityLabel(cues.joined(separator: ". "))
    }

    private func run() async {
        guard cues.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled, isRunning else { continue }
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
                .animation(.linear(duration: 0.09), value: progress)

            // Scaled rather than sized: a font size recomputed per frame snaps
            // to its new value while the ring is still travelling, so the
            // numeral arrived before the circle around it did.
            Text("\(seconds)")
                .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText(countsDown: true))
                .animation(.smooth(duration: 0.26), value: seconds)
                .foregroundStyle(.white)
                .scaleEffect(diameter / 76)
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
