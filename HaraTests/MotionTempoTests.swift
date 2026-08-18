import Foundation
import Testing
@testable import Hara

@Suite("Motion tempo")
struct MotionTempoTests {
    static let tempos: [(name: String, tempo: MotionTempo)] = [
        ("controlled", .controlled),
        ("deliberate", .deliberate),
        ("explosive", .explosive),
        ("isometric", .isometric)
    ]

    @Test("The envelope stays within 0 and 1")
    func envelopeIsBounded() {
        for (name, tempo) in Self.tempos {
            for step in 0...1_000 {
                let value = tempo.envelope(at: Float(step) / 1_000)
                #expect(value >= 0 && value <= 1, "\(name) produced \(value)")
            }
        }
    }

    @Test("The cycle starts and ends fully relaxed")
    func envelopeClosesTheLoop() {
        for (name, tempo) in Self.tempos {
            #expect(tempo.envelope(at: 0) == 0, "\(name) does not start relaxed")
            #expect(tempo.envelope(at: 0.9999) < 0.001, "\(name) does not finish relaxed")
        }
    }

    @Test("Every tempo reaches full contraction")
    func envelopeReachesPeak() {
        for (name, tempo) in Self.tempos {
            let peak = (0...1_000).map { tempo.envelope(at: Float($0) / 1_000) }.max() ?? 0
            #expect(peak > 0.999, "\(name) never fully contracts")
            #expect(tempo.envelope(at: tempo.peakPhase) > 0.999, "\(name) mislabels its peak")
        }
    }

    @Test("The effort ramps without a velocity jump")
    func envelopeIsSmooth() {
        // A step in the curve would show up on screen as a jolt, so no single
        // sample may move much more than its neighbours.
        for (name, tempo) in Self.tempos {
            var deltas: [Float] = []
            for step in 0..<2_000 {
                let current = tempo.envelope(at: Float(step) / 2_000)
                let next = tempo.envelope(at: Float(step + 1) / 2_000)
                deltas.append(abs(next - current))
            }
            #expect(deltas.max() ?? 0 < 0.01, "\(name) has a step of \(deltas.max() ?? 0)")
        }
    }

    @Test("The return is slower than the lift")
    func eccentricIsSlowerThanConcentric() {
        // The whole point of the tempo model: effort is quick, control is slow.
        for (name, tempo) in [Self.tempos[0], Self.tempos[1], Self.tempos[2]] {
            #expect(tempo.eccentric > tempo.concentric, "\(name) returns faster than it lifts")
        }
    }

    @Test("Invalid fractions cannot produce a divide by zero")
    func degenerateTemposStaySafe() {
        let tempo = MotionTempo(concentric: 0, squeeze: -5, eccentric: 0, recover: -1)

        for step in 0...100 {
            let value = tempo.envelope(at: Float(step) / 100)
            #expect(value.isFinite && value >= 0 && value <= 1)
        }
        #expect(tempo.peakPhase.isFinite)
    }

    @Test("Oscillation swings between both extremes")
    func oscillationCoversBothSides() {
        for dwell in [Float(0), 0.2, 0.3, 0.45] {
            let samples = (0...1_000).map { MotionTempo.oscillation(at: Float($0) / 1_000, dwell: dwell) }
            #expect(samples.allSatisfy { $0 >= -1.001 && $0 <= 1.001 })
            #expect((samples.max() ?? 0) > 0.999, "dwell \(dwell) never reaches +1")
            #expect((samples.min() ?? 0) < -0.999, "dwell \(dwell) never reaches -1")
        }
    }

    @Test("Oscillation is smooth and closes its loop")
    func oscillationIsSmooth() {
        for dwell in [Float(0), 0.3, 0.45] {
            var deltas: [Float] = []
            for step in 0..<2_000 {
                let current = MotionTempo.oscillation(at: Float(step) / 2_000, dwell: dwell)
                let next = MotionTempo.oscillation(at: Float(step + 1) / 2_000, dwell: dwell)
                deltas.append(abs(next - current))
            }
            #expect(deltas.max() ?? 0 < 0.02, "dwell \(dwell) steps by \(deltas.max() ?? 0)")
            #expect(
                abs(MotionTempo.oscillation(at: 0, dwell: dwell)
                    - MotionTempo.oscillation(at: 0.9999, dwell: dwell)) < 0.01
            )
        }
    }

    @Test("A larger dwell holds the extremes for longer")
    func dwellExtendsTheHold() {
        func timeAtExtreme(_ dwell: Float) -> Int {
            (0...1_000).count { abs(MotionTempo.oscillation(at: Float($0) / 1_000, dwell: dwell)) > 0.999 }
        }

        #expect(timeAtExtreme(0.4) > timeAtExtreme(0.1))
    }

    @Test("Wrapping normalises any phase into one cycle")
    func wrapNormalisesPhase() {
        #expect(MotionTempo.wrap(0) == 0)
        #expect(abs(MotionTempo.wrap(1) - 0) < 0.0001)
        #expect(abs(MotionTempo.wrap(2.25) - 0.25) < 0.0001)
        #expect(abs(MotionTempo.wrap(-0.25) - 0.75) < 0.0001)
        #expect(MotionTempo.wrap(.nan) == 0)
        #expect(MotionTempo.wrap(.infinity) == 0)
    }

    @Test("Smoothstep eases in and out")
    func smoothstepEases() {
        #expect(MotionTempo.smoothstep(0) == 0)
        #expect(MotionTempo.smoothstep(1) == 1)
        #expect(abs(MotionTempo.smoothstep(0.5) - 0.5) < 0.0001)
        #expect(MotionTempo.smoothstep(-3) == 0)
        #expect(MotionTempo.smoothstep(4) == 1)
        // Slow at the ends, fast in the middle.
        #expect(MotionTempo.smoothstep(0.1) < 0.1)
        #expect(MotionTempo.smoothstep(0.9) > 0.9)
    }

    @Test("Isometric holds still breathe")
    func holdsKeepMoving() {
        for motion in [MotionKind.plank, .hollowHold, .bearHold, .rest] {
            let tempo = MotionLibrary.tempo(for: motion)
            #expect(tempo == .isometric, "\(motion.rawValue) should be an isometric hold")
        }
    }
}
