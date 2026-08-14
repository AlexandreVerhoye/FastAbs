import SwiftUI
import Testing
import simd
@testable import FastAbs

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
            let bounds = FigureProjection.bounds(for: motion)
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
            let bounds = FigureProjection.bounds(for: motion)
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
            let bounds = FigureProjection.bounds(for: motion)
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
            let bounds = FigureProjection.bounds(for: motion)
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
            within: FigureProjection.bounds(for: .bicycle),
            in: CGRect(x: 0, y: 0, width: 320, height: 400)
        )

        #expect(layout.leftHip.depth > layout.rightHip.depth, "the sides are not separated in depth")
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
            let bounds = FigureProjection.bounds(for: motion)
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
