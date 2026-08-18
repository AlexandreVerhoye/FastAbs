import SwiftUI
import Testing
import simd
@testable import Hara

/// The figure is now plain SwiftUI drawing, which means it can be rasterised
/// and checked pixel by pixel — something the RealityKit avatar it replaced
/// could never be tested for at all.
@MainActor
@Suite("Exercise figure")
struct FigureTests {
    static let allMotions = MotionSystemTests.allMotions

    // MARK: - Framing

    @Test("Framing holds every pose of the movement")
    func boundsContainTheWholeCycle() {
        for motion in Self.allMotions {
            let bounds = FigureProjection.measureBounds(for: motion)
            #expect(bounds.width > 0 && bounds.height > 0, "\(motion.rawValue) has no framing")

            for step in 0..<40 {
                let pose = MotionLibrary.pose(for: motion, phase: Float(step) / 40)
                for joint in pose.joints {
                    let point = FigureProjection.flatten(joint)
                    #expect(
                        bounds.contains(point),
                        "\(motion.rawValue) leaves \(point) outside its framing"
                    )
                }
            }
        }
    }

    @Test("Framing leaves room for the body drawn around the joints")
    func boundsPadForTheSilhouette() {
        // Joints sit at the centre of the limbs, so framing them tightly would
        // clip the athlete's outline at the edges of the card.
        for motion in Self.allMotions {
            let bounds = FigureProjection.measureBounds(for: motion)
            var tight = CGRect.null
            for step in 0..<40 {
                let pose = MotionLibrary.pose(for: motion, phase: Float(step) / 40)
                for joint in pose.joints {
                    tight = tight.union(CGRect(origin: FigureProjection.flatten(joint), size: .zero))
                }
            }
            #expect(bounds.minX < tight.minX - 0.1, "\(motion.rawValue) has no left margin")
            #expect(bounds.maxX > tight.maxX + 0.1, "\(motion.rawValue) has no right margin")
        }
    }

    @Test("The athlete never changes size mid-movement")
    func scaleIsStableAcrossACycle() {
        // Framing is computed once per movement precisely so the figure cannot
        // swell and shrink as the pose widens and narrows.
        let rect = CGRect(x: 0, y: 0, width: 320, height: 400)

        for motion in Self.allMotions {
            let bounds = FigureProjection.measureBounds(for: motion)
            let scales = (0..<24).map { step -> CGFloat in
                let pose = MotionLibrary.pose(for: motion, phase: Float(step) / 24)
                return FigureProjection.layout(pose: pose, within: bounds, in: rect).scale
            }
            #expect(
                (scales.max() ?? 0) - (scales.min() ?? 0) < 0.0001,
                "\(motion.rawValue) rescales during its cycle"
            )
            #expect((scales.first ?? 0) > 0)
        }
    }

    @Test("The laid-out figure lands inside the space it is given")
    func layoutFitsItsRect() {
        let rect = CGRect(x: 0, y: 0, width: 320, height: 400)

        for motion in Self.allMotions {
            let bounds = FigureProjection.measureBounds(for: motion)
            for step in 0..<16 {
                let pose = MotionLibrary.pose(for: motion, phase: Float(step) / 16)
                let layout = FigureProjection.layout(pose: pose, within: bounds, in: rect)
                for joint in layout.joints {
                    #expect(
                        rect.insetBy(dx: -1, dy: -1).contains(joint.point),
                        "\(motion.rawValue) places a joint at \(joint.point)"
                    )
                }
            }
        }
    }

    @Test("Sideways movement survives the flattening")
    func lateralMotionStaysVisible() {
        // A pure side-on projection would collapse a bicycle crunch and a set of
        // scissors into the same picture, so the projection mixes in some of the
        // sideways axis.
        let left = FigureProjection.flatten(SIMD3<Float>(0, 0, 0.3))
        let right = FigureProjection.flatten(SIMD3<Float>(0, 0, -0.3))
        #expect(abs(left.x - right.x) > 0.1, "sideways movement is invisible")

        let up = FigureProjection.flatten(SIMD3<Float>(0, 1, 0))
        let down = FigureProjection.flatten(SIMD3<Float>(0, 0, 0))
        #expect(up.y < down.y, "the world's up must become the screen's up")
    }

    @Test("Depth is carried through so limbs can be ordered")
    func layoutKeepsDepth() {
        let pose = MotionLibrary.pose(for: .bicycle, phase: 0.3)
        let layout = FigureProjection.layout(
            pose: pose,
            within: FigureProjection.measureBounds(for: .bicycle),
            in: CGRect(x: 0, y: 0, width: 320, height: 400)
        )

        #expect(
            abs(layout.leftHip.depth - layout.rightHip.depth) > 0.1,
            "the sides are not separated in depth"
        )
        #expect(abs(layout.front.dx) + abs(layout.front.dy) > 0.9, "the facing direction is not a unit vector")
    }

    // MARK: - Muscle colour

    @Test("A resting muscle is the body's own white")
    func restingMuscleDisappears() {
        let resting = PixelColor(MuscleHeat.color(for: 0))
        #expect(resting.saturation < 0.03, "resting muscle is tinted")
        #expect(resting.brightness > 0.9)
        #expect(MuscleHeat.opacity(for: 0) < 0.2, "resting muscle is drawn too solidly")
    }

    @Test("A contracted muscle is unmistakably red")
    func peakMuscleIsRed() {
        let peak = PixelColor(MuscleHeat.color(for: 1))
        #expect(peak.red > 0.7 && peak.green < 0.3 && peak.blue < 0.3)
        #expect(MuscleHeat.opacity(for: 1) > 0.95)
    }

    @Test("The ramp only ever moves toward red")
    func rampIsMonotonic() {
        var previousGreen = 1.1
        var previousOpacity = -1.0

        for step in 0...100 {
            let intensity = Float(step) / 100
            let colour = PixelColor(MuscleHeat.color(for: intensity))
            #expect(colour.green <= previousGreen + 0.001, "green rises again at \(intensity)")
            #expect(MuscleHeat.opacity(for: intensity) >= previousOpacity - 0.001)
            previousGreen = colour.green
            previousOpacity = MuscleHeat.opacity(for: intensity)
        }
    }

    @Test("Invalid intensities cannot produce an invalid colour")
    func rampIsSafe() {
        for intensity in [Float.nan, .infinity, -.infinity, -3, 9] {
            let colour = PixelColor(MuscleHeat.color(for: intensity))
            #expect(colour.red.isFinite && colour.green.isFinite && colour.blue.isFinite)
            let opacity = MuscleHeat.opacity(for: intensity)
            #expect(opacity.isFinite && opacity >= 0 && opacity <= 1)
        }
    }

    // MARK: - Rendering

    private func render(
        _ motion: MotionKind,
        phase: Float,
        focus: Set<MuscleZone> = [.fullCore],
        _ label: String
    ) -> RenderedView? {
        VisualProbe.require(
            FigureCanvas(motion: motion, phase: phase, focus: focus),
            width: 300,
            height: 320,
            colorScheme: .dark,
            label
        )
    }

    @Test("Every exercise actually draws an athlete")
    func everyMotionRenders() {
        for motion in Self.allMotions {
            guard let rendered = render(motion, phase: 0.3, "\(motion.rawValue)") else { return }

            #expect(!rendered.isBlank, "\(motion.rawValue) renders nothing")
            // A recognisable body covers a real share of the card — enough to
            // catch a figure that has collapsed to a line or a dot.
            #expect(
                rendered.paintedRatio > 0.05,
                "\(motion.rawValue) covers only \(rendered.paintedRatio) of the card"
            )
            #expect(
                rendered.paintedRatio < 0.75,
                "\(motion.rawValue) fills the card — the framing has broken"
            )
        }
    }

    @Test("The athlete is white")
    func figureReadsAsWhite() {
        guard let rendered = render(.plank, phase: 0.5, "plank") else { return }
        let bright = rendered.pixels.filter { $0.alpha > 0.05 && $0.brightness > 0.7 }

        #expect(bright.count > rendered.pixelCount / 20, "the body is not bright enough to read as white")
        // The muscle map is deliberately red, so the claim is that the body is
        // white *apart from* the working muscles — not that no pixel is tinted.
        let uncoloured = bright.count { $0.saturation < 0.35 }
        #expect(
            Double(uncoloured) / Double(bright.count) > 0.85,
            "only \(uncoloured) of \(bright.count) lit pixels are white — the body has a colour cast"
        )
    }

    @Test("A working muscle paints red on the body")
    func workingMuscleShowsRed() {
        // A crunch at peak contraction against the same crunch fully relaxed:
        // the difference has to be visible red, or the whole feature is invisible.
        let tempo = MotionLibrary.tempo(for: .crunch)
        guard
            let relaxed = render(.crunch, phase: 0, focus: [.upperAbs], "relaxed crunch"),
            let contracted = render(.crunch, phase: tempo.peakPhase, focus: [.upperAbs], "contracted crunch")
        else { return }

        func redPixels(_ view: RenderedView) -> Int {
            view.pixels.count { $0.alpha > 0.05 && $0.red > $0.green + 0.15 && $0.red > $0.blue + 0.15 }
        }

        #expect(redPixels(contracted) > 100, "peak contraction shows almost no red")
        #expect(
            redPixels(contracted) > redPixels(relaxed) * 2,
            "the muscle map barely changes between relaxed and contracted"
        )
    }

    @Test("Rest shows an athlete with no effort on them")
    func recoveryStaysCalm() {
        guard let rendered = render(.rest, phase: 0.4, "recovery") else { return }

        let red = rendered.pixels.count { $0.alpha > 0.05 && $0.red > $0.green + 0.2 }
        #expect(!rendered.isBlank)
        #expect(red < rendered.pixelCount / 200, "recovery is lit up like an effort")
    }

    @Test("The movement visibly changes through its cycle")
    func framesDifferAcrossACycle() {
        for motion in Self.allMotions {
            guard
                let start = render(motion, phase: 0, "\(motion.rawValue) start"),
                let middle = render(motion, phase: 0.35, "\(motion.rawValue) middle")
            else { return }

            #expect(
                start.difference(from: middle) > 0.002,
                "\(motion.rawValue) looks identical at rest and mid-repetition"
            )
        }
    }

    @Test("The loop closes without a jump")
    func loopIsSeamless() {
        for motion in Self.allMotions {
            guard
                let first = render(motion, phase: 0, "\(motion.rawValue) first"),
                let last = render(motion, phase: 0.999, "\(motion.rawValue) last")
            else { return }

            #expect(
                first.difference(from: last) < 0.02,
                "\(motion.rawValue) jumps when the loop restarts"
            )
        }
    }

    @Test("The focused zone is the one that lights up")
    func focusDrivesTheHighlight() {
        let tempo = MotionLibrary.tempo(for: .bicycle)
        guard
            let obliques = render(.bicycle, phase: tempo.peakPhase, focus: [.obliques], "oblique focus"),
            let lower = render(.bicycle, phase: tempo.peakPhase, focus: [.lowerAbs], "lower focus")
        else { return }

        #expect(
            obliques.difference(from: lower) > 0.001,
            "the catalog's focus makes no difference to what is highlighted"
        )
    }
}

/// A single frame of the figure, isolated so tests can rasterise it without a
/// running clock.
private struct FigureCanvas: View {
    let motion: MotionKind
    let phase: Float
    let focus: Set<MuscleZone>

    var body: some View {
        Canvas { context, size in
            let bounds = FigureProjection.measureBounds(for: motion)
            let layout = FigureProjection.layout(
                pose: MotionLibrary.pose(for: motion, phase: phase),
                within: bounds,
                in: CGRect(origin: .zero, size: size)
            )
            FigureRenderer(
                layout: layout,
                activation: MuscleActivation.make(for: motion, phase: phase, focus: focus)
            ).draw(into: &context)
        }
    }
}

/// Holes come from subpaths wound against each other under the non-zero fill
/// rule. They are invisible in code review and glaring on screen.
///
/// The check is per body part, not on the assembled figure: the triangle under
/// a raised bridge is genuinely enclosed by the pose and is meant to be empty,
/// whereas a single part must always be solid.
@MainActor
@Suite("Figure solidity")
struct FigureSolidityTests {
    @Test("Every body part fills solid")
    func partsAreSolid() {
        for motion in MotionSystemTests.allMotions {
            for phase in [Float(0), 0.3, 0.6] {
                for part in FigureRenderer.Part.everything {
                    guard let rendered = VisualProbe.require(
                        PartCanvas(motion: motion, phase: phase, part: part),
                        width: 240,
                        height: 240,
                        colorScheme: .dark,
                        "\(motion.rawValue) \(part) at \(phase)"
                    ) else { return }

                    #expect(
                        enclosedEmptyPixels(in: rendered) < 25,
                        """
                        \(motion.rawValue) \(part) at \(phase) has \
                        \(enclosedEmptyPixels(in: rendered)) enclosed empty pixels
                        """
                    )
                }
            }
        }
    }

    /// Empty pixels the background cannot reach by flooding in from the border.
    private func enclosedEmptyPixels(in rendered: RenderedView) -> Int {
        let width = rendered.width
        let height = rendered.height
        var empty = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                empty[y * width + x] = rendered.pixel(x: x, y: y).alpha <= 0.05
            }
        }

        var reached = [Bool](repeating: false, count: width * height)
        var queue: [Int] = []

        func visit(_ x: Int, _ y: Int) {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            let index = y * width + x
            guard !reached[index], empty[index] else { return }
            reached[index] = true
            queue.append(index)
        }

        for x in 0..<width {
            visit(x, 0)
            visit(x, height - 1)
        }
        for y in 0..<height {
            visit(0, y)
            visit(width - 1, y)
        }
        while let index = queue.popLast() {
            visit(index % width - 1, index / width)
            visit(index % width + 1, index / width)
            visit(index % width, index / width - 1)
            visit(index % width, index / width + 1)
        }

        return (0..<(width * height)).count { empty[$0] && !reached[$0] }
    }
}

private struct PartCanvas: View {
    let motion: MotionKind
    let phase: Float
    let part: FigureRenderer.Part

    var body: some View {
        Canvas { context, size in
            let layout = FigureProjection.layout(
                pose: MotionLibrary.pose(for: motion, phase: phase),
                within: FigureProjection.measureBounds(for: motion),
                in: CGRect(origin: .zero, size: size)
            )
            let renderer = FigureRenderer(layout: layout, activation: .idle)
            context.fill(renderer.path(for: part), with: .color(.white))
        }
    }
}

/// The history surface: work split across the body, and the bests.
@Suite("History analytics")
struct HistoryAnalyticsTests {
    private func record(
        _ exercises: [String],
        seconds: Int = 420,
        daysAgo: Int = 0
    ) -> WorkoutRecord {
        let plan = WorkoutEngine().makePlan(preferences: .recommended, seed: 1)
        let stored = WorkoutRecord(
            plan: plan,
            completedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
            activeDuration: seconds
        )
        stored.exerciseIDs = exercises
        stored.plannedDuration = seconds
        stored.plannedActiveDuration = seconds
        return stored
    }

    @Test("The balance is read from what was actually trained")
    func patternLoadReflectsTheExercises() {
        // Not from the focus the athlete asked for: what counts is the work done.
        let analytics = WorkoutHistoryAnalytics()
        let load = analytics.patternLoad(records: [
            record(["forearm-plank", "hollow-hold"], daysAgo: 1),
            record(["side-plank"], daysAgo: 2),
            record(["classic-crunch"], daysAgo: 3)
        ])

        #expect(Set(load.map(\.pattern)) == [.antiExtension, .antiLateralFlexion, .dynamicFlexion])
        #expect(load.allSatisfy { $0.activeSeconds > 0 })
        #expect(load == load.sorted { $0.activeSeconds > $1.activeSeconds }, "not ordered by load")
    }

    @Test("A session spanning several jobs splits its time between them")
    func mixedSessionsSplitTheirTime() {
        // Counting the full session against every job it touched would make one
        // varied week look like three weeks of training.
        let analytics = WorkoutHistoryAnalytics()
        let load = analytics.patternLoad(records: [
            record(["forearm-plank", "classic-crunch"], seconds: 600)
        ])

        #expect(load.reduce(0) { $0 + $1.activeSeconds } <= 600)
        #expect(load.count == 2)
    }

    @Test("Records report the best, not the latest")
    func personalRecordsFindTheBest() {
        let analytics = WorkoutHistoryAnalytics()
        let bests = analytics.personalRecords(records: [
            record(["classic-crunch"], seconds: 400, daysAgo: 40),
            record(["classic-crunch"], seconds: 900, daysAgo: 20),
            record(["classic-crunch"], seconds: 500, daysAgo: 1),
            record(["classic-crunch"], seconds: 480, daysAgo: 1)
        ])

        #expect(bests.longestSessionSeconds == 900)
        #expect(bests.busiestDaySessions == 2)
        #expect(bests.totalSessions == 4)
        #expect(bests.bestWeekMinutes > 0)
        #expect(bests.hasAny)
    }

    @Test("An empty history reports nothing rather than zeroes dressed as records")
    func emptyHistoryHasNoRecords() {
        let bests = WorkoutHistoryAnalytics().personalRecords(records: [])
        #expect(!bests.hasAny)
        #expect(WorkoutHistoryAnalytics().patternLoad(records: []).isEmpty)
    }

    @Test("A stored session counts a held movement once, not twice")
    func recordsCountMovementsNotSteps() {
        // The two halves of a side plank are two steps and one movement; a
        // record that listed the id twice would double it in every statistic.
        let plan = WorkoutEngine().makePlan(
            preferences: TestSupport.preferences(durationMinutes: 16, apartmentFriendly: false),
            seed: 5
        )
        let record = WorkoutRecord(plan: plan)
        #expect(record.exerciseIDs.count == plan.movements.count)
        #expect(Set(record.exerciseIDs).count == record.exerciseIDs.count)
    }
}

// A whole-figure hole test was tried here and removed. The idea was to flood
// fill from the border and treat any sealed background as a hole one part had
// punched in another. It cannot work: the renderer's separation gap — the thin
// line that keeps an arm from merging into the torso it lies on — is itself a
// sealed region, and a bridge or a hand behind the head encloses a real pocket.
// Every discriminator tried (size, erosion, connected components) either passed
// genuine cuts or failed the feature. What remains is `FigureSolidityTests`,
// which renders each part alone and so can only see holes that are certainly
// wrong, plus the contact sheet in `MotionContactSheet` for the rest. Reading a
// picture is not automation, but a threshold tuned until today's output passes
// asserts nothing except that nothing changed.

/// One frame of one movement, sized for rasterising.
struct MotionFigure: View {
    let motion: MotionKind
    let phase: Float

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let layout = FigureProjection.layout(
                pose: MotionLibrary.pose(for: motion, phase: phase),
                within: FigureProjection.bounds(for: motion),
                in: CGRect(origin: .zero, size: size)
            )
            FigureRenderer(
                layout: layout,
                activation: MuscleActivation.make(for: motion, phase: phase)
            ).draw(into: &context)
        }
    }
}
