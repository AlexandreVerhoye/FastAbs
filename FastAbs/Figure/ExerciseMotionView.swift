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
    /// Seeded at init rather than in `onAppear`: a paused figure renders once,
    /// and that render happened before `onAppear` could supply the framing —
    /// which left every still thumbnail blank.
    @State private var bounds: CGRect
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
        _bounds = State(initialValue: FigureProjection.bounds(for: motion))
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

        TimelineView(
            .animation(minimumInterval: 1.0 / 40, paused: !isPlaying || reduceMotion)
        ) { timeline in
            ExerciseFigure(
                motion: motion,
                phase: phase(at: timeline.date, cadence: Double(metadata.cyclesPerSecond)),
                focusZones: focusZones,
                bounds: bounds
            )
        }
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
    }
}

/// Turns a laid-out pose into a drawn athlete.
///
/// The figure is built from five solid shapes — two arms, two legs and the
/// trunk — rather than a set of strokes. Each is punched out of whatever has
/// already been drawn before being filled, so an arm crossing the chest leaves
/// a clean gap instead of dissolving into it. That separation is what turns a
/// white blob into a readable body; without it every overlap merges.
struct FigureRenderer {
    let layout: FigureLayout
    let activation: MuscleActivation

    func draw(into context: inout GraphicsContext) {
        // Painted back to front, so a limb on the far side of the body is
        // covered by the near one rather than the other way round.
        for part in orderedParts() {
            switch part {
            case .arm(let side):
                let arm = armPath(side)
                place(arm, cutting: armPath(side, trimmedAtRoot: true), shade: shade(forArm: side), into: &context)
                drawLimbMuscles(on: .arm(side), clippedTo: arm, into: &context)
            case .leg(let side):
                let leg = legPath(side)
                place(leg, cutting: legPath(side, trimmedAtRoot: true), shade: shade(forLeg: side), into: &context)
                drawLimbMuscles(on: .leg(side), clippedTo: leg, into: &context)
            case .trunk:
                let trunk = trunkPath()
                let group = trunkGroupPath(trunk: trunk)
                place(group, cutting: group, shade: FigureShading.near, into: &context)
                drawMuscles(clippedTo: trunk, into: &context)
            }
        }
    }

    /// Cuts a shape out of the drawing so far, then fills it.
    ///
    /// The cut is a stroke along the shape's own outline: half of it falls
    /// outside the shape and survives the fill, which is exactly the gap that
    /// separates this part from whatever sits behind it.
    private func place(
        _ path: Path,
        cutting cutShape: Path,
        shade: Color,
        into context: inout GraphicsContext
    ) {
        // A part is separated from everything it crosses, but not from the body
        // it grows out of, so the cut shape is the limb trimmed back from its
        // root joint. Trimming beats subtracting a disc: no path boolean runs
        // in the frame loop at all.
        var cut = context
        cut.blendMode = .destinationOut
        cut.stroke(
            cutShape,
            with: .color(.white),
            style: StrokeStyle(
                lineWidth: FigureMetrics.separation * 2 * layout.scale,
                lineCap: .round,
                lineJoin: .round
            )
        )
        context.fill(path, with: .color(shade))
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

    func shade(forArm side: Side) -> Color {
        FigureShading.body(atDepth: side == .left ? layout.leftElbow.depth : layout.rightElbow.depth)
    }

    func shade(forLeg side: Side) -> Color {
        FigureShading.body(atDepth: side == .left ? layout.leftKnee.depth : layout.rightKnee.depth)
    }
}

// MARK: - Body shapes

private extension FigureRenderer {
    /// A limb segment: a capsule that tapers from one joint to the next.
    ///
    /// Real limbs are thicker at the shoulder than the wrist and at the hip
    /// than the ankle. Drawing every segment at one width is most of what made
    /// the earlier figure read as inflated tubing.
    func segment(from start: CGPoint, to end: CGPoint, startWidth: CGFloat, endWidth: CGFloat) -> Path {
        var path = Path()
        appendSegment(to: &path, from: start, to: end, startWidth: startWidth, endWidth: endWidth)
        return path
    }

    /// Appends one tapered capsule as a single closed outline.
    ///
    /// Built as two tangent lines and two end caps rather than a rectangle
    /// unioned with two circles. Path booleans are expensive and this runs for
    /// every limb of every frame; traced directly it costs nothing, and
    /// overlapping subpaths already merge under the non-zero fill rule.
    func appendSegment(
        to path: inout Path,
        from start: CGPoint,
        to end: CGPoint,
        startWidth: CGFloat,
        endWidth: CGFloat,
        capSegments: Int = 10
    ) {
        let scale = layout.scale
        let startRadius = max(startWidth * scale / 2, 0.01)
        let endRadius = max(endWidth * scale / 2, 0.01)
        let span = hypot(end.x - start.x, end.y - start.y)

        guard span > 0.001 else {
            appendCircle(to: &path, centre: start, radius: startRadius)
            return
        }

        let heading = atan2(end.y - start.y, end.x - start.x)
        // Where the outline leaves the caps: a wider end tilts the tangent.
        let taper = asin(min(max((startRadius - endRadius) / span, -1), 1))
        let near = heading + .pi / 2 + taper
        let far = heading - .pi / 2 - taper

        func point(_ centre: CGPoint, _ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
            CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
        }

        path.move(to: point(start, startRadius, near))
        path.addLine(to: point(end, endRadius, near))
        // Round the far cap, sweeping through the heading.
        let farSweep = CGFloat.pi + 2 * taper
        for step in 1...capSegments {
            let angle = near - farSweep * CGFloat(step) / CGFloat(capSegments)
            path.addLine(to: point(end, endRadius, angle))
        }
        path.addLine(to: point(start, startRadius, far))
        // And the near cap, sweeping back the other side.
        let nearSweep = CGFloat.pi - 2 * taper
        for step in 1...capSegments {
            let angle = far - nearSweep * CGFloat(step) / CGFloat(capSegments)
            path.addLine(to: point(start, startRadius, angle))
        }
        path.closeSubpath()
    }

    /// A circle traced the same way round as `appendSegment` traces its caps.
    ///
    /// `Path(ellipseIn:)` winds the other way, and under the non-zero fill rule
    /// an opposite winding cancels where it overlaps — which is why the head was
    /// punching a hole through the shoulders on every single pose.
    func appendCircle(to path: inout Path, centre: CGPoint, radius: CGFloat, segments: Int = 24) {
        guard radius > 0.01 else { return }
        path.move(to: CGPoint(x: centre.x + radius, y: centre.y))
        for step in 1...segments {
            let angle = -2 * CGFloat.pi * CGFloat(step) / CGFloat(segments)
            path.addLine(to: CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius))
        }
        path.closeSubpath()
    }

    /// `trimmedAtRoot` starts the shape a little way down the limb, which is how
    /// the separation cut is kept off the hip and the shoulder.
    func armPath(_ side: Side, trimmedAtRoot: Bool = false) -> Path {
        let (shoulder, elbow, hand) = side == .left
            ? (layout.leftShoulder, layout.leftElbow, layout.leftHand)
            : (layout.rightShoulder, layout.rightElbow, layout.rightHand)

        // The hand runs on past the wrist rather than stopping at it, so the
        // arm ends in something shaped like a hand instead of a blunt cap.
        let reach = elbow.point.direction(to: hand.point)
        let fingertips = hand.point + reach * (FigureMetrics.handLength * layout.scale)
        let start = trimmedAtRoot
            ? shoulder.point + shoulder.point.direction(to: elbow.point) * (FigureMetrics.rootJoin * layout.scale)
            : shoulder.point

        var path = Path()
        appendSegment(
            to: &path, from: start, to: elbow.point,
            startWidth: FigureMetrics.upperArmTop, endWidth: FigureMetrics.upperArmBottom
        )
        appendSegment(
            to: &path, from: elbow.point, to: hand.point,
            startWidth: FigureMetrics.forearmTop, endWidth: FigureMetrics.forearmBottom
        )
        appendSegment(
            to: &path, from: hand.point, to: fingertips,
            startWidth: FigureMetrics.handWidth, endWidth: FigureMetrics.handWidth * 0.7
        )
        return path
    }

    func legPath(_ side: Side, trimmedAtRoot: Bool = false) -> Path {
        let (hip, knee, ankle, toe) = side == .left
            ? (layout.leftHip, layout.leftKnee, layout.leftAnkle, layout.leftToe)
            : (layout.rightHip, layout.rightKnee, layout.rightAnkle, layout.rightToe)

        let start = trimmedAtRoot
            ? hip.point + hip.point.direction(to: knee.point) * (FigureMetrics.rootJoin * layout.scale)
            : hip.point

        var path = Path()
        appendSegment(
            to: &path, from: start, to: knee.point,
            startWidth: FigureMetrics.thighTop, endWidth: FigureMetrics.thighBottom
        )
        appendSegment(
            to: &path, from: knee.point, to: ankle.point,
            startWidth: FigureMetrics.shinTop, endWidth: FigureMetrics.shinBottom
        )
        appendSegment(
            to: &path, from: ankle.point, to: toe.point,
            startWidth: FigureMetrics.footHeel, endWidth: FigureMetrics.footToe
        )
        return path
    }

    /// Trunk, neck and head as one shape, so the head sits on the shoulders
    /// instead of being separated from them by a gap.
    func trunkGroupPath(trunk: Path) -> Path {
        let scale = layout.scale
        let headCentre = CGPoint(
            x: layout.chest.point.x + (layout.head.point.x - layout.chest.point.x) * FigureMetrics.headSeating,
            y: layout.chest.point.y + (layout.head.point.y - layout.chest.point.y) * FigureMetrics.headSeating
        )

        var path = trunk
        appendSegment(
            to: &path, from: layout.chest.point, to: headCentre,
            startWidth: FigureMetrics.neck, endWidth: FigureMetrics.neck * 0.85
        )
        appendCircle(to: &path, centre: headCentre, radius: FigureMetrics.headRadius * scale)
        return path
    }

    /// The silhouette of the trunk: shoulders down to the seat, taken in at the
    /// waist. Seen from the side its width is the body's depth, not the span of
    /// the shoulders.
    func trunkPath() -> Path {
        let axis = layout.pelvis.point.direction(to: layout.chest.point)
        let across = axis.perpendicular
        let scale = layout.scale

        let seat = layout.pelvis.point - axis * (FigureMetrics.seatOverhang * scale)
        let top = layout.chest.point + axis * (FigureMetrics.chestOverhang * scale)
        let waist = layout.pelvis.point.midpoint(to: layout.chest.point)

        let chestHalf = FigureMetrics.chestHalfDepth * scale
        let waistHalf = FigureMetrics.waistHalfDepth * scale
        let seatHalf = FigureMetrics.seatHalfDepth * scale

        var path = Path()
        path.move(to: seat - across * seatHalf)
        path.addQuadCurve(to: top - across * chestHalf, control: waist - across * (waistHalf * 0.78))
        path.addQuadCurve(
            to: top + across * chestHalf,
            control: top + axis * (FigureMetrics.shoulderCrown * scale)
        )
        path.addQuadCurve(to: seat + across * seatHalf, control: waist + across * (waistHalf * 0.78))
        path.addQuadCurve(
            to: seat - across * seatHalf,
            control: seat - axis * (FigureMetrics.seatCrown * scale)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Limb muscles

/// A muscle group that lives on a limb rather than on the trunk.
///
/// Adding a leg or an upper-body movement needs no new drawing code: it needs
/// a row here saying which segment the group sits on, how far along it runs and
/// which face of the limb it is on.
struct LimbMuscle {
    enum Segment { case upperArm, forearm, thigh, shin }

    let zone: MuscleZone
    let segment: Segment
    /// Where the group starts and ends along its segment, as a fraction.
    let along: ClosedRange<CGFloat>
    /// Which face of the limb: +1 is the side the body faces, -1 the back.
    let facing: CGFloat
    /// Share of the limb's width the group covers.
    let spread: CGFloat

    static let all: [LimbMuscle] = [
        LimbMuscle(zone: .quadriceps, segment: .thigh, along: 0.18...0.88, facing: 1, spread: 0.62),
        LimbMuscle(zone: .hamstrings, segment: .thigh, along: 0.2...0.85, facing: -1, spread: 0.58),
        LimbMuscle(zone: .calves, segment: .shin, along: 0.12...0.65, facing: -1, spread: 0.6),
        LimbMuscle(zone: .shoulders, segment: .upperArm, along: 0...0.34, facing: 0, spread: 0.86),
        LimbMuscle(zone: .arms, segment: .upperArm, along: 0.32...0.92, facing: 1, spread: 0.6)
    ]
}

private extension FigureRenderer {
    /// Paints every muscle group that belongs to this limb, inside its outline.
    func drawLimbMuscles(on part: Part, clippedTo limb: Path, into context: inout GraphicsContext) {
        let segments: [LimbMuscle.Segment]
        switch part {
        case .arm: segments = [.upperArm, .forearm]
        case .leg: segments = [.thigh, .shin]
        case .trunk: return
        }

        context.drawLayer { layer in
            layer.clip(to: limb)
            for muscle in LimbMuscle.all where segments.contains(muscle.segment) {
                let intensity = activation[muscle.zone]
                guard intensity > 0.02 else { continue }
                guard let bounds = bounds(of: muscle.segment, on: part) else { continue }
                layer.fill(band(for: muscle, on: bounds), with: .color(paint(intensity)))
            }
        }
    }

    /// The two ends of a limb segment, and how wide it is at each.
    func bounds(
        of segment: LimbMuscle.Segment,
        on part: Part
    ) -> (start: CGPoint, end: CGPoint, startWidth: CGFloat, endWidth: CGFloat)? {
        switch (part, segment) {
        case (.arm(let side), .upperArm):
            let joints = side == .left
                ? (layout.leftShoulder, layout.leftElbow)
                : (layout.rightShoulder, layout.rightElbow)
            return (joints.0.point, joints.1.point, FigureMetrics.upperArmTop, FigureMetrics.upperArmBottom)
        case (.arm(let side), .forearm):
            let joints = side == .left
                ? (layout.leftElbow, layout.leftHand)
                : (layout.rightElbow, layout.rightHand)
            return (joints.0.point, joints.1.point, FigureMetrics.forearmTop, FigureMetrics.forearmBottom)
        case (.leg(let side), .thigh):
            let joints = side == .left
                ? (layout.leftHip, layout.leftKnee)
                : (layout.rightHip, layout.rightKnee)
            return (joints.0.point, joints.1.point, FigureMetrics.thighTop, FigureMetrics.thighBottom)
        case (.leg(let side), .shin):
            let joints = side == .left
                ? (layout.leftKnee, layout.leftAnkle)
                : (layout.rightKnee, layout.rightAnkle)
            return (joints.0.point, joints.1.point, FigureMetrics.shinTop, FigureMetrics.shinBottom)
        default:
            return nil
        }
    }

    func band(
        for muscle: LimbMuscle,
        on bounds: (start: CGPoint, end: CGPoint, startWidth: CGFloat, endWidth: CGFloat)
    ) -> Path {
        let axis = bounds.start.direction(to: bounds.end)
        let length = hypot(bounds.end.x - bounds.start.x, bounds.end.y - bounds.start.y)

        // The face of the limb the group sits on, taken from the way the body
        // is turned so a quadriceps stays at the front however the leg swings.
        var across = axis.perpendicular
        if muscle.facing != 0 {
            let sign: CGFloat = (across.dx * layout.front.dx + across.dy * layout.front.dy) >= 0 ? 1 : -1
            across = across * (sign * muscle.facing)
        }

        let midpoint = (muscle.along.lowerBound + muscle.along.upperBound) / 2
        let width = (bounds.startWidth + (bounds.endWidth - bounds.startWidth) * midpoint) * layout.scale
        let centre = CGPoint(
            x: bounds.start.x + (bounds.end.x - bounds.start.x) * midpoint,
            y: bounds.start.y + (bounds.end.y - bounds.start.y) * midpoint
        ) + (muscle.facing == 0 ? CGVector(dx: 0, dy: 0) : across * (width * 0.24))

        return rounded(
            centre: centre,
            across: across,
            along: axis,
            halfWidth: width * muscle.spread / 2,
            halfHeight: length * (muscle.along.upperBound - muscle.along.lowerBound) / 2
        )
    }
}

// MARK: - Trunk muscles

private extension FigureRenderer {
    /// The abdominal map, painted inside the trunk so it takes the body's own
    /// outline and can never spill past its edge.
    func drawMuscles(clippedTo trunk: Path, into context: inout GraphicsContext) {
        let axis = layout.pelvis.point.direction(to: layout.chest.point)
        let scale = layout.scale
        let length = hypot(
            layout.chest.point.x - layout.pelvis.point.x,
            layout.chest.point.y - layout.pelvis.point.y
        )

        // The belly direction, squared up against the trunk so a band sits flat
        // on the abdomen whichever way the athlete has turned.
        let facing = layout.front
        let alongAxis = facing.dx * axis.dx + facing.dy * axis.dy
        var belly = CGVector(dx: facing.dx - axis.dx * alongAxis, dy: facing.dy - axis.dy * alongAxis)
        let bellyLength = (belly.dx * belly.dx + belly.dy * belly.dy).squareRoot()
        belly = bellyLength > 0.0001
            ? CGVector(dx: belly.dx / bellyLength, dy: belly.dy / bellyLength)
            : axis.perpendicular

        // Kept just inside the trunk so their own rounded ends show. Run edge
        // to edge and they meet the body's outline square, which reads as a
        // strip of tape rather than a muscle.
        let bands: [(intensity: Float, along: CGFloat, height: CGFloat)] = [
            (activation.lowerAbs, 0.3, 0.22),
            (activation.upperAbs, 0.56, 0.22),
            (activation.chest, 0.85, 0.24)
        ]

        context.drawLayer { layer in
            layer.clip(to: trunk)

            for band in bands where band.intensity > 0.02 {
                let centre = layout.pelvis.point + axis * (band.along * length)
                layer.fill(
                    rounded(
                        centre: centre,
                        across: belly,
                        along: axis,
                        halfWidth: FigureMetrics.bandHalfWidth * scale,
                        halfHeight: band.height * length / 2
                    ),
                    with: .color(paint(band.intensity))
                )
            }

            // Obliques hug the flanks, so they sit at the trunk's edges rather
            // than across the middle of the belly.
            // The posterior groups sit on the far face of the trunk, which is
            // the same construction as an oblique on the flank.
            for (intensity, along, height) in [
                (activation.glutes, CGFloat(0.06), CGFloat(0.3)),
                (activation.lowerBack, CGFloat(0.3), CGFloat(0.3)),
                (activation.upperBack, CGFloat(0.72), CGFloat(0.3))
            ] where intensity > 0.02 {
                layer.fill(
                    rounded(
                        centre: layout.pelvis.point
                            + axis * (along * length)
                            - belly * (FigureMetrics.obliqueOffset * scale),
                        across: belly,
                        along: axis,
                        halfWidth: FigureMetrics.obliqueWidth * scale / 2,
                        halfHeight: height * length / 2
                    ),
                    with: .color(paint(intensity))
                )
            }

            for (intensity, side) in [
                (activation.leftOblique, CGFloat(1)),
                (activation.rightOblique, CGFloat(-1))
            ] where intensity > 0.02 {
                let centre = layout.pelvis.point
                    + axis * (0.44 * length)
                    + belly * (side * FigureMetrics.obliqueOffset * scale)
                layer.fill(
                    rounded(
                        centre: centre,
                        across: belly,
                        along: axis,
                        halfWidth: FigureMetrics.obliqueWidth * scale / 2,
                        halfHeight: 0.36 * length / 2
                    ),
                    with: .color(paint(intensity))
                )
            }
        }
    }

    func paint(_ intensity: Float) -> Color {
        MuscleHeat.color(for: intensity).opacity(MuscleHeat.opacity(for: intensity))
    }

    /// A rounded rectangle laid out in the trunk's own axes, so it stays square
    /// to the body however the athlete turns.
    func rounded(
        centre: CGPoint,
        across: CGVector,
        along: CGVector,
        halfWidth: CGFloat,
        halfHeight: CGFloat
    ) -> Path {
        let path = Path(
            roundedRect: CGRect(
                x: -halfWidth,
                y: -halfHeight,
                width: halfWidth * 2,
                height: halfHeight * 2
            ),
            cornerRadius: min(halfWidth, halfHeight) * 0.72
        )
        return path.applying(
            CGAffineTransform(
                a: across.dx, b: across.dy,
                c: along.dx, d: along.dy,
                tx: centre.x, ty: centre.y
            )
        )
    }
}
