import SwiftUI

/// The exercise demonstration: a clean white athlete with the working muscles
/// picked out in red.
///
/// Callers choose the movement and whether it is playing; everything below —
/// the pose engine, the repetition tempo, the muscle activation model — stays
/// behind this interface.
struct ExerciseMotionView: View {
    let motion: MotionKind
    var isPlaying: Bool
    var focusZones: Set<MuscleZone>
    var accessibilityName: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Framing for the whole movement, so the athlete never pulses in size.
    @State private var bounds: CGRect = .zero
    /// Cycles completed before the current run of playback.
    @State private var completedCycles: Double = 0
    @State private var runStartedAt = Date.now

    init(
        motion: MotionKind,
        isPlaying: Bool = true,
        focusZones: Set<MuscleZone> = [.fullCore],
        accessibilityName: String? = nil
    ) {
        self.motion = motion
        self.isPlaying = isPlaying
        self.focusZones = focusZones
        self.accessibilityName = accessibilityName
    }

    init(exercise: Exercise, isPlaying: Bool = true) {
        self.init(
            motion: exercise.motion,
            isPlaying: isPlaying,
            focusZones: exercise.zones,
            accessibilityName: exercise.name
        )
    }

    var body: some View {
        let metadata = MotionLibrary.metadata(for: motion)

        TimelineView(.animation(paused: !isPlaying || reduceMotion)) { timeline in
            ExerciseFigure(
                motion: motion,
                phase: phase(at: timeline.date, cadence: Double(metadata.cyclesPerSecond)),
                focusZones: focusZones,
                bounds: bounds
            )
        }
        .onAppear { refreshFraming() }
        .onChange(of: motion) { _, _ in
            refreshFraming()
            completedCycles = 0
            runStartedAt = .now
        }
        .onChange(of: isPlaying) { _, playing in
            let cadence = Double(MotionLibrary.metadata(for: motion).cyclesPerSecond)
            if playing {
                runStartedAt = .now
            } else {
                completedCycles += Date.now.timeIntervalSince(runStartedAt) * cadence
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Démonstration — \(accessibilityName ?? metadata.title)")
        .accessibilityValue(metadata.accessibilityDescription)
        .accessibilityHint(
            reduceMotion
                ? "Image fixe sur la contraction maximale, selon votre réglage Réduire les animations."
                : "Le mouvement est présenté en boucle. Les muscles sollicités passent du blanc au rouge."
        )
    }

    private func refreshFraming() {
        bounds = FigureProjection.bounds(for: motion)
    }

    private func phase(at date: Date, cadence: Double) -> Float {
        // With Reduce Motion on, hold the peak contraction: a frozen mid-rep
        // teaches nothing, a frozen squeeze teaches the movement.
        guard !reduceMotion else { return MotionLibrary.tempo(for: motion).peakPhase }
        guard isPlaying else { return Float(completedCycles) }
        return Float(completedCycles + date.timeIntervalSince(runStartedAt) * cadence)
    }
}

/// Draws one frame of the athlete.
private struct ExerciseFigure: View {
    let motion: MotionKind
    let phase: Float
    let focusZones: Set<MuscleZone>
    let bounds: CGRect

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            guard bounds.width > 0, bounds.height > 0 else { return }

            let pose = MotionLibrary.pose(for: motion, phase: phase)
            let activation = MuscleActivation.make(for: motion, phase: phase, focus: focusZones)
            let layout = FigureProjection.layout(
                pose: pose,
                within: bounds,
                in: CGRect(origin: .zero, size: size)
            )

            FigureRenderer(layout: layout, activation: activation).draw(into: &context)
        }
        .drawingGroup()
    }
}

/// Turns a laid-out pose into strokes and fills.
///
/// Everything is drawn with round caps and joins in a single family of whites,
/// so overlapping parts merge into one silhouette instead of showing seams —
/// the thing a three-dimensional assembly of parts can never quite manage.
struct FigureRenderer {
    let layout: FigureLayout
    let activation: MuscleActivation

    func draw(into context: inout GraphicsContext) {
        // Painted back to front so a limb on the far side of the body never
        // covers the near one.
        for part in orderedParts() {
            switch part {
            case .arm(let side): drawArm(side, into: &context)
            case .leg(let side): drawLeg(side, into: &context)
            case .trunk: drawTrunk(into: &context)
            }
        }
    }
}

// MARK: - Ordering

private extension FigureRenderer {
    enum Side { case left, right }
    enum Part { case arm(Side), leg(Side), trunk }

    func orderedParts() -> [Part] {
        let parts: [(Part, CGFloat)] = [
            (.arm(.left), (layout.leftShoulder.depth + layout.leftElbow.depth + layout.leftHand.depth) / 3),
            (.arm(.right), (layout.rightShoulder.depth + layout.rightElbow.depth + layout.rightHand.depth) / 3),
            (.leg(.left), (layout.leftHip.depth + layout.leftKnee.depth + layout.leftAnkle.depth) / 3),
            (.leg(.right), (layout.rightHip.depth + layout.rightKnee.depth + layout.rightAnkle.depth) / 3),
            (.trunk, 0)
        ]
        return parts.sorted { $0.1 < $1.1 }.map(\.0)
    }

    func joints(forArm side: Side) -> (FigureJoint, FigureJoint, FigureJoint) {
        side == .left
            ? (layout.leftShoulder, layout.leftElbow, layout.leftHand)
            : (layout.rightShoulder, layout.rightElbow, layout.rightHand)
    }

    func joints(forLeg side: Side) -> (FigureJoint, FigureJoint, FigureJoint, FigureJoint) {
        side == .left
            ? (layout.leftHip, layout.leftKnee, layout.leftAnkle, layout.leftToe)
            : (layout.rightHip, layout.rightKnee, layout.rightAnkle, layout.rightToe)
    }
}

// MARK: - Limbs

private extension FigureRenderer {
    func drawArm(_ side: Side, into context: inout GraphicsContext) {
        let (shoulder, elbow, hand) = joints(forArm: side)
        let shade = FigureShading.body(atDepth: elbow.depth)

        stroke(from: shoulder.point, to: elbow.point, width: FigureMetrics.upperArm, shade, &context)
        stroke(from: elbow.point, to: hand.point, width: FigureMetrics.forearm, shade, &context)
        dot(at: hand.point, radius: FigureMetrics.handRadius, shade, &context)
    }

    func drawLeg(_ side: Side, into context: inout GraphicsContext) {
        let (hip, knee, ankle, toe) = joints(forLeg: side)
        let shade = FigureShading.body(atDepth: knee.depth)

        stroke(from: hip.point, to: knee.point, width: FigureMetrics.thigh, shade, &context)
        stroke(from: knee.point, to: ankle.point, width: FigureMetrics.shin, shade, &context)
        stroke(from: ankle.point, to: toe.point, width: FigureMetrics.footWidth, shade, &context)
    }

    func stroke(
        from start: CGPoint,
        to end: CGPoint,
        width: CGFloat,
        _ shade: Color,
        _ context: inout GraphicsContext
    ) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(
            path,
            with: .color(shade),
            style: StrokeStyle(lineWidth: width * layout.scale, lineCap: .round, lineJoin: .round)
        )
    }

    func dot(at centre: CGPoint, radius: CGFloat, _ shade: Color, _ context: inout GraphicsContext) {
        let size = radius * layout.scale
        context.fill(
            Path(ellipseIn: CGRect(x: centre.x - size, y: centre.y - size, width: size * 2, height: size * 2)),
            with: .color(shade)
        )
    }
}

// MARK: - Trunk and muscles

private extension FigureRenderer {
    func drawTrunk(into context: inout GraphicsContext) {
        let shade = FigureShading.near
        let trunk = trunkPath()

        // The skull sits lower than the skeleton's head joint. Drawing it at the
        // joint left a visible stalk of neck between it and the shoulders, which
        // reads as a lollipop rather than a person.
        let headCentre = CGPoint(
            x: layout.chest.point.x + (layout.head.point.x - layout.chest.point.x) * FigureMetrics.headSeating,
            y: layout.chest.point.y + (layout.head.point.y - layout.chest.point.y) * FigureMetrics.headSeating
        )
        stroke(from: layout.chest.point, to: headCentre, width: FigureMetrics.neck, shade, &context)

        context.fill(trunk, with: .color(shade))
        drawMuscles(clippedTo: trunk, into: &context)
        dot(at: headCentre, radius: FigureMetrics.headRadius, shade, &context)
    }

    /// The silhouette of the trunk.
    ///
    /// Built as a slim quadrilateral and then stroked with a wide round join:
    /// the stroke both fattens the shape to its real width and rounds every
    /// corner, which is far more reliable than hand-placing curve controls —
    /// those left the shoulders ending in a visible point.
    func trunkPath() -> Path {
        let axis = layout.pelvis.point.direction(to: layout.chest.point)
        let across = axis.perpendicular
        let scale = layout.scale

        let seat = layout.pelvis.point - axis * (FigureMetrics.seatOverhang * scale)
        let top = layout.chest.point + axis * (FigureMetrics.chestOverhang * scale)
        let waist = layout.pelvis.point.midpoint(to: layout.chest.point)

        // Seen from the side the trunk is as wide as the body is deep, not as
        // wide as the shoulders span.
        let chestHalf = FigureMetrics.chestHalfDepth * scale
        let waistHalf = FigureMetrics.waistHalfDepth * scale
        let seatHalf = FigureMetrics.seatHalfDepth * scale

        var path = Path()
        path.move(to: seat - across * seatHalf)
        path.addLine(to: waist - across * waistHalf)
        path.addLine(to: top - across * chestHalf)
        path.addLine(to: top + across * chestHalf)
        path.addLine(to: waist + across * waistHalf)
        path.addLine(to: seat + across * seatHalf)
        path.closeSubpath()

        return path.strokedPath(
            StrokeStyle(lineWidth: FigureMetrics.trunkRounding * scale, lineCap: .round, lineJoin: .round)
        ).union(path)
    }

    /// The abdominal map, painted inside the trunk so it can never spill past
    /// the body's edge.
    func drawMuscles(clippedTo trunk: Path, into context: inout GraphicsContext) {
        let axis = layout.pelvis.point.direction(to: layout.chest.point)
        let scale = layout.scale
        let length = hypot(
            layout.chest.point.x - layout.pelvis.point.x,
            layout.chest.point.y - layout.pelvis.point.y
        )

        // The belly direction, squared up against the trunk so a band always
        // sits flat on the abdomen whichever way the athlete has turned.
        let facing = layout.front
        let alongFacing = facing.dx * axis.dx + facing.dy * axis.dy
        var bellyVector = CGVector(dx: facing.dx - axis.dx * alongFacing, dy: facing.dy - axis.dy * alongFacing)
        let bellyLength = (bellyVector.dx * bellyVector.dx + bellyVector.dy * bellyVector.dy).squareRoot()
        if bellyLength > 0.0001 {
            bellyVector = CGVector(dx: bellyVector.dx / bellyLength, dy: bellyVector.dy / bellyLength)
        } else {
            bellyVector = axis.perpendicular
        }

        // Whole regions rather than a grid of tiles: clipped to the body, a
        // region reads as "this muscle is working", a tile reads as a sticker.
        let bands: [(intensity: Float, along: CGFloat, belly: CGFloat, depth: CGFloat, height: CGFloat)] = [
            (activation.lowerAbs, 0.32, 0.03, 0.29, 0.26),
            (activation.upperAbs, 0.6, 0.03, 0.29, 0.26),
            (activation.leftOblique, 0.46, -0.1, 0.12, 0.4),
            (activation.rightOblique, 0.46, -0.1, 0.12, 0.4)
        ]

        context.drawLayer { layer in
            layer.clip(to: trunk)
            for band in bands where band.intensity > 0.02 {
                let centre = layout.pelvis.point
                    + axis * (band.along * length)
                    + bellyVector * (band.belly * scale)
                let halfDepth = band.depth * scale / 2
                let halfHeight = band.height * length / 2

                let rounded = Path(
                    roundedRect: CGRect(
                        x: -halfDepth,
                        y: -halfHeight,
                        width: halfDepth * 2,
                        height: halfHeight * 2
                    ),
                    cornerRadius: min(halfDepth, halfHeight) * 0.7
                )
                // The band's own axes are the trunk's, so it stays square to the
                // body however the athlete turns.
                let placement = CGAffineTransform(
                    a: bellyVector.dx, b: bellyVector.dy,
                    c: axis.dx, d: axis.dy,
                    tx: centre.x, ty: centre.y
                )

                layer.fill(
                    rounded.applying(placement),
                    with: .color(
                        MuscleHeat.color(for: band.intensity)
                            .opacity(MuscleHeat.opacity(for: band.intensity))
                    )
                )
            }
        }
    }
}
