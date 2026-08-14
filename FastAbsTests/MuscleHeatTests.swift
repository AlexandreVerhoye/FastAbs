import SwiftUI
import Testing
import UIKit
@testable import FastAbs

/// The white-body, red-muscle look is the feature the user sees, so the ramp
/// that produces it is tested as carefully as the geometry that moves it.
@MainActor
@Suite("Muscle heat")
struct MuscleHeatTests {
    private func components(_ color: UIColor) -> (red: Double, green: Double, blue: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }

    @Test("A resting muscle is the same white as the body")
    func restingMuscleIsInvisible() {
        // An unworked group has to disappear into the silhouette: any tint at
        // zero intensity would read as "this muscle is working a little".
        let resting = components(MuscleHeatPalette.color(for: 0))
        let skin = components(MuscleHeatPalette.restingColor)

        #expect(abs(resting.red - skin.red) < 0.001)
        #expect(abs(resting.green - skin.green) < 0.001)
        #expect(abs(resting.blue - skin.blue) < 0.001)
        #expect(resting.red > 0.9 && resting.green > 0.9 && resting.blue > 0.9, "the body is not white")
    }

    @Test("A fully contracted muscle is deep red")
    func peakMuscleIsRed() {
        let peak = components(MuscleHeatPalette.color(for: 1))

        #expect(peak.red > 0.7, "peak contraction is not red enough")
        #expect(peak.green < 0.25 && peak.blue < 0.25, "peak contraction is not saturated")
    }

    @Test("Intensity ramps monotonically from white to red")
    func rampIsMonotonic() {
        var previousGreen = 1.1
        var previousDistanceFromWhite = -1.0

        for step in 0...100 {
            let intensity = Float(step) / 100
            let colour = components(MuscleHeatPalette.color(for: intensity))
            let distanceFromWhite = abs(colour.red - 0.95) + abs(colour.green - 0.95) + abs(colour.blue - 0.95)

            // Green drains away as the muscle loads, and the colour moves
            // steadily further from the resting white. Either reversing would
            // make a rising effort look like a falling one.
            #expect(colour.green <= previousGreen + 0.001, "green rises again at \(intensity)")
            #expect(
                distanceFromWhite >= previousDistanceFromWhite - 0.001,
                "the ramp doubles back at \(intensity)"
            )
            previousGreen = colour.green
            previousDistanceFromWhite = distanceFromWhite
        }
    }

    @Test("Every intensity produces a usable colour")
    func rampIsAlwaysValid() {
        for step in -20...120 {
            let colour = components(MuscleHeatPalette.color(for: Float(step) / 100))
            for channel in [colour.red, colour.green, colour.blue] {
                #expect(channel.isFinite && channel >= 0 && channel <= 1, "step \(step) gave \(colour)")
            }
        }
        for invalid in [Float.nan, .infinity, -.infinity] {
            let colour = components(MuscleHeatPalette.color(for: invalid))
            #expect(colour.red.isFinite && colour.green.isFinite && colour.blue.isFinite)
        }
    }

    @Test("Steps span the whole ladder without running off it")
    func stepsAreBounded() {
        #expect(MuscleHeatPalette.step(for: 0) == 0)
        #expect(MuscleHeatPalette.step(for: 1) == MuscleHeatPalette.stepCount - 1)
        #expect(MuscleHeatPalette.step(for: -5) == 0)
        #expect(MuscleHeatPalette.step(for: 5) == MuscleHeatPalette.stepCount - 1)
        #expect(MuscleHeatPalette.step(for: .nan) == 0)

        for step in 0..<MuscleHeatPalette.stepCount {
            let intensity = Float(step) / Float(MuscleHeatPalette.stepCount - 1)
            #expect(MuscleHeatPalette.step(for: intensity) == step, "step \(step) does not round-trip")
        }
    }

    @Test("The ladder is fine enough that intensity looks continuous")
    func ladderIsSmoothEnough() {
        // Adjacent steps must not be far enough apart to read as banding.
        for step in 1..<MuscleHeatPalette.stepCount {
            let previous = components(MuscleHeatPalette.color(for: Float(step - 1) / Float(MuscleHeatPalette.stepCount - 1)))
            let current = components(MuscleHeatPalette.color(for: Float(step) / Float(MuscleHeatPalette.stepCount - 1)))
            let jump = abs(previous.red - current.red)
                + abs(previous.green - current.green)
                + abs(previous.blue - current.blue)
            #expect(jump < 0.2, "steps \(step - 1)→\(step) jump by \(jump)")
        }
        #expect(MuscleHeatPalette.stepCount >= 12, "too few steps to hide banding")
    }

    @Test("Out-of-range ladder lookups clamp instead of crashing")
    func ladderLookupIsSafe() {
        _ = MuscleHeatPalette.material(atStep: -10)
        _ = MuscleHeatPalette.material(atStep: 9_999)
    }

    @Test("The abdominal wall covers every zone the app can highlight")
    func abdominalWallIsComplete() {
        let panels = MusclePanel.abdominalWall()
        let groups = Set(panels.map(\.group))

        #expect(groups.contains(.upperAbs))
        #expect(groups.contains(.lowerAbs))
        #expect(groups.contains(.leftOblique))
        #expect(groups.contains(.rightOblique))
        #expect(panels.count >= 6, "the wall is too coarse to show upper and lower work separately")
    }

    @Test("The abdominal wall is laid out symmetrically")
    func abdominalWallIsSymmetric() {
        let panels = MusclePanel.abdominalWall()

        for panel in panels {
            let mirrored = panels.first {
                abs($0.centerAngle + panel.centerAngle) < 0.0001
                    && abs($0.height - panel.height) < 0.0001
                    && abs($0.halfWidth - panel.halfWidth) < 0.0001
            }
            #expect(mirrored != nil, "no mirror for a band at \(panel.centerAngle), \(panel.height)")
        }

        // Upper segments sit above lower ones, or the heat map would be upside down.
        let upper = panels.filter { $0.group == .upperAbs }.map(\.height).min() ?? 0
        let lower = panels.filter { $0.group == .lowerAbs }.map(\.height).max() ?? 1
        #expect(upper > lower, "the upper abs are drawn below the lower abs")
    }

    @Test("Bands sit on the abdomen and wrap the right way round")
    func panelsStayOnTheTorso() {
        for panel in MusclePanel.abdominalWall() {
            // Heights are in the torso's own mesh space, where -0.5 is the hips
            // and +0.5 the shoulders: a band must stay clear of both ends.
            #expect(panel.height > -0.4 && panel.height < 0.3, "a band sits off the abdomen")
            #expect(panel.bandHeight > 0.05 && panel.bandHeight < 0.5)
            #expect(panel.halfWidth > 0.1 && panel.halfWidth < 0.7, "a band wraps too far around")

            // Nothing may wrap past the flank onto the athlete's back.
            let outerEdge = abs(panel.centerAngle) + panel.halfWidth
            #expect(outerEdge < .pi / 2, "a band reaches around to the back")
        }
    }

    @Test("Rectus segments stay in front and obliques stay on the flanks")
    func bandsSitWhereTheirMuscleIs() {
        for panel in MusclePanel.abdominalWall() {
            switch panel.group {
            case .upperAbs, .lowerAbs:
                #expect(abs(panel.centerAngle) < .pi / 4, "a rectus segment wrapped onto the flank")
            case .leftOblique:
                #expect(panel.centerAngle > .pi / 6, "the left oblique is not on the left flank")
            case .rightOblique:
                #expect(panel.centerAngle < -.pi / 6, "the right oblique is not on the right flank")
            }
        }
    }

    @Test("Each panel reads the intensity of its own group")
    func panelsTrackTheirGroup() {
        let activation = MuscleActivation(
            upperAbs: 0.9, lowerAbs: 0.1,
            leftOblique: 0.7, rightOblique: 0.2,
            deepCore: 0.5, lowerBack: 0.3
        )

        for panel in MusclePanel.abdominalWall() {
            let expected: Float
            switch panel.group {
            case .upperAbs: expected = 0.9
            case .lowerAbs: expected = 0.1
            case .leftOblique: expected = 0.7
            case .rightOblique: expected = 0.2
            }
            #expect(panel.intensity(in: activation) == expected)
        }
    }

    @Test("A working muscle is visibly redder than a resting one on screen")
    func workingMuscleReadsAsRed() {
        let resting = MuscleHeatPalette.color(for: 0)
        let working = MuscleHeatPalette.color(for: 0.5)
        let peak = MuscleHeatPalette.color(for: 1)

        let restingPixel = PixelColor(Color(uiColor: resting))
        let workingPixel = PixelColor(Color(uiColor: working))
        let peakPixel = PixelColor(Color(uiColor: peak))

        // Each stage must be clearly separable at a glance, not a subtle shift.
        #expect(restingPixel.distance(to: workingPixel) > 0.15)
        #expect(workingPixel.distance(to: peakPixel) > 0.1)
        #expect(restingPixel.saturation < 0.05, "resting muscle is tinted")
        #expect(peakPixel.saturation > 0.8, "peak muscle is washed out")
    }
}
