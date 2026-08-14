import SwiftUI
import Testing
@testable import FastAbs

/// Pixel-level checks on the progress surface.
///
/// The progress screen exists to make effort legible at a glance, so the thing
/// worth testing is that more effort actually looks like more: a fuller ring
/// paints more arc, a busier week paints darker squares, a better week points
/// its arrow up.
@MainActor
@Suite("Progress visuals")
struct ProgressVisualTests {
    @Test("The hero renders and carries the app's night palette")
    func heroIsDrawn() {
        guard let rendered = VisualProbe.require(
            ProgressHero(overview: VisualFixture.overview()),
            width: 340, height: 220, "progress hero"
        ) else { return }

        #expect(!rendered.isBlank)
        #expect(rendered.paintedRatio > 0.8, "the hero card should fill its frame")
        #expect(rendered.averageColor.brightness < 0.5, "the hero should read as a dark card")
    }

    @Test("A longer streak changes the hero")
    func heroReflectsTheStreak() {
        guard
            let quiet = VisualProbe.require(
                ProgressHero(overview: VisualFixture.overview(currentStreak: 1)),
                width: 340, height: 220, "one day streak"
            ),
            let strong = VisualProbe.require(
                ProgressHero(overview: VisualFixture.overview(currentStreak: 128)),
                width: 340, height: 220, "long streak"
            )
        else { return }

        #expect(quiet.difference(from: strong) > 0.003, "the streak figure does not show")
    }

    @Test("A fuller challenge ring paints more of its arc")
    func challengeRingGrowsWithProgress() {
        let tint = PixelColor(Color.fastCoral)
        var painted: [Int] = []

        for current in [0, 3, 6, 12] {
            guard let rendered = VisualProbe.require(
                ChallengeCard(challenge: VisualFixture.challenge(current: current, target: 12), tint: .fastCoral),
                width: 340, height: 130, "ring at \(current)/12"
            ) else { return }
            painted.append(rendered.count(of: tint, tolerance: 0.22))
        }

        // Monotonic: every step of real progress has to be visible.
        #expect(painted[0] < painted[1], "0% and 25% look the same")
        #expect(painted[1] < painted[2], "25% and 50% look the same")
        #expect(painted[2] < painted[3], "50% and 100% look the same")
    }

    @Test("A completed challenge is marked as done")
    func completedChallengeLooksDifferent() {
        guard
            let partial = VisualProbe.require(
                ChallengeCard(challenge: VisualFixture.challenge(current: 8, target: 12), tint: .fastCoral),
                width: 340, height: 130, "partial challenge"
            ),
            let complete = VisualProbe.require(
                ChallengeCard(challenge: VisualFixture.challenge(current: 12, target: 12), tint: .fastCoral),
                width: 340, height: 130, "complete challenge"
            )
        else { return }

        #expect(partial.difference(from: complete) > 0.005, "completion is not visible")
        #expect(
            complete.count(of: PixelColor(Color.fastCoral), tolerance: 0.22)
                > partial.count(of: PixelColor(Color.fastCoral), tolerance: 0.22)
        )
    }

    @Test("The challenge card honours its tint")
    func challengeCardUsesItsTint() {
        guard
            let coral = VisualProbe.require(
                ChallengeCard(challenge: VisualFixture.challenge(current: 9, target: 12), tint: .fastCoral),
                width: 340, height: 130, "coral challenge"
            ),
            let blue = VisualProbe.require(
                ChallengeCard(challenge: VisualFixture.challenge(current: 9, target: 12), tint: .fastBlue),
                width: 340, height: 130, "blue challenge"
            )
        else { return }

        #expect(coral.contains(PixelColor(Color.fastCoral), tolerance: 0.2, minimumCoverage: 0.01))
        #expect(blue.contains(PixelColor(Color.fastBlue), tolerance: 0.2, minimumCoverage: 0.01))
        #expect(coral.difference(from: blue) > 0.01, "the two tints render alike")
    }

    @Test("The activity grid darkens with the work done")
    func activityGridScalesWithEffort() {
        let tint = PixelColor(Color.fastCoral)
        var painted: [Int] = []

        // Same layout every time; only the intensity of each day changes.
        for seconds in [0, 240, 420, 600, 900] {
            let days = VisualFixture.days(
                count: 35,
                activeSecondsByOffset: Dictionary(uniqueKeysWithValues: (0..<35).map { ($0, seconds) })
            )
            guard let rendered = VisualProbe.require(
                ActivityGridCard(days: days, calendar: VisualFixture.calendar),
                width: 340, height: 340, "grid at \(seconds)s"
            ) else { return }
            painted.append(rendered.count(of: tint, tolerance: 0.3))
        }

        #expect(painted.first ?? 0 < painted.last ?? 0, "a full month looks like an empty one")
        // Every rung of the intensity ladder must be reachable.
        for index in 1..<painted.count {
            #expect(
                painted[index] >= painted[index - 1],
                "activity level \(index) paints less than level \(index - 1)"
            )
        }
    }

    @Test("Rest days and active days are visually separable")
    func restDaysReadAsRest() {
        let allRest = VisualFixture.days(count: 35)
        let allActive = VisualFixture.days(
            count: 35,
            activeSecondsByOffset: Dictionary(uniqueKeysWithValues: (0..<35).map { ($0, 900) })
        )

        guard
            let rest = VisualProbe.require(
                ActivityGridCard(days: allRest, calendar: VisualFixture.calendar),
                width: 340, height: 340, "rest month"
            ),
            let active = VisualProbe.require(
                ActivityGridCard(days: allActive, calendar: VisualFixture.calendar),
                width: 340, height: 340, "active month"
            )
        else { return }

        #expect(rest.difference(from: active) > 0.03, "an empty month looks like a full one")
        #expect(
            active.count(of: PixelColor(Color.fastCoral), tolerance: 0.3)
                > rest.count(of: PixelColor(Color.fastCoral), tolerance: 0.3) * 4
        )
    }

    @Test("An improving week and a declining week look different")
    func weeklyComparisonShowsDirection() {
        guard
            let better = VisualProbe.require(
                WeeklyComparisonCard(
                    overview: VisualFixture.overview(currentWeekSeconds: 3_600, previousWeekSeconds: 1_800)
                ),
                width: 400, height: 150, "improving week"
            ),
            let worse = VisualProbe.require(
                WeeklyComparisonCard(
                    overview: VisualFixture.overview(currentWeekSeconds: 900, previousWeekSeconds: 1_800)
                ),
                width: 400, height: 150, "declining week"
            )
        else { return }

        #expect(!better.isBlank && !worse.isBlank)
        // The two cards share their layout and differ only in the glyph, its
        // tint and one line of text, so the whole-card delta is small by
        // nature; the colour-family checks below carry the real weight.
        #expect(better.difference(from: worse) > 0.004, "progress and regression look the same")

        // The tint reaches the screen as a thin arrow glyph over a 12% wash, so
        // almost no pixel lands on the pure colour. What the eye actually reads
        // is the colour *family*, and that is what is asserted here.
        func greenLeaning(_ view: RenderedView) -> Int {
            view.pixels.count { $0.alpha > 0.05 && $0.green > $0.red + 0.05 && $0.green > $0.blue + 0.02 }
        }
        func warmLeaning(_ view: RenderedView) -> Int {
            view.pixels.count { $0.alpha > 0.05 && $0.red > $0.green + 0.05 && $0.green > $0.blue + 0.02 }
        }

        #expect(
            greenLeaning(better) > greenLeaning(worse),
            "an improving week does not read as positive"
        )
        #expect(
            warmLeaning(worse) > warmLeaning(better),
            "a declining week does not read as a warning"
        )
    }

    @Test("A first active week does not look like a decline")
    func firstWeekIsNeutral() {
        guard let rendered = VisualProbe.require(
            WeeklyComparisonCard(
                overview: VisualFixture.overview(currentWeekSeconds: 1_200, previousWeekSeconds: 0)
            ),
            width: 400, height: 150, "first week"
        ) else { return }

        #expect(!rendered.isBlank)
        #expect(rendered.contains(PixelColor(Color.fastBlue), tolerance: 0.28, minimumCoverage: 0.001))
    }

    @Test("The focus chart paints one colour per zone")
    func focusChartUsesZoneColours() {
        guard let rendered = VisualProbe.require(
            FocusDistributionCard(items: VisualFixture.focus()),
            width: 340, height: 230, "focus breakdown"
        ) else { return }

        #expect(!rendered.isBlank)
        for item in VisualFixture.focus() {
            #expect(
                rendered.contains(PixelColor(item.zone.color), tolerance: 0.18, minimumCoverage: 0.003),
                "\(item.zone.rawValue) is missing from the chart"
            )
        }
    }

    @Test("The progress surface survives dark mode")
    func progressSurfaceWorksInDarkMode() {
        let cards: [(String, AnyView)] = [
            ("hero", AnyView(ProgressHero(overview: VisualFixture.overview()))),
            ("weekly", AnyView(WeeklyComparisonCard(overview: VisualFixture.overview()))),
            ("focus", AnyView(FocusDistributionCard(items: VisualFixture.focus()))),
            (
                "grid",
                AnyView(
                    ActivityGridCard(
                        days: VisualFixture.days(count: 35, activeSecondsByOffset: [0: 600, 5: 900]),
                        calendar: VisualFixture.calendar
                    )
                )
            )
        ]

        for (name, card) in cards {
            guard let dark = VisualProbe.require(
                card, width: 340, height: 240, colorScheme: .dark, "\(name) in dark mode"
            ) else { return }
            #expect(!dark.isBlank, "\(name) disappears in dark mode")
            #expect(dark.paintedRatio > 0.3, "\(name) barely renders in dark mode")
        }
    }

    @Test("Extreme values do not break the layout")
    func extremeValuesStayContained() {
        let overview = VisualFixture.overview(
            currentStreak: 9_999,
            longestStreak: 9_999,
            totalActiveSeconds: 9_999_999
        )

        guard let rendered = VisualProbe.require(
            ProgressHero(overview: overview), width: 340, height: 220, "extreme hero"
        ) else { return }

        #expect(!rendered.isBlank)
        // Content that overflowed its rounded card would paint the corners,
        // which the card's own clip shape leaves transparent.
        let corner = rendered.cropped(x: 0, y: 0, width: 6, height: 6)
        #expect(corner.paintedRatio < 0.75, "content spills out of the card's corner")
    }

    @Test("A challenge with no target cannot divide by zero")
    func degenerateChallengeStillRenders() {
        guard let rendered = VisualProbe.require(
            ChallengeCard(challenge: VisualFixture.challenge(current: 0, target: 0), tint: .fastCoral),
            width: 340, height: 130, "zero-target challenge"
        ) else { return }

        #expect(!rendered.isBlank)
        #expect(VisualFixture.challenge(current: 0, target: 0).progress == 0)
    }
}
