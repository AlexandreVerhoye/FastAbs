import SwiftUI
import Testing
@testable import Hara

/// Pixel-level checks on the rewards surface.
///
/// A badge is a purely visual reward: its tier, its colour and the difference
/// between earned and unearned are the whole feature, and none of that is
/// covered by asserting on model values.
@MainActor
@Suite("Badge visuals")
struct BadgeVisualTests {
    @Test("A badge actually renders something")
    func badgeIsDrawn() {
        guard let rendered = VisualProbe.require(
            MiniBadgeView(badge: VisualFixture.badge(tier: .gold)),
            width: 120,
            height: 120,
            "gold badge"
        ) else { return }

        #expect(!rendered.isBlank, "the badge canvas came out empty")
        #expect(rendered.paintedRatio > 0.15, "only \(rendered.paintedRatio) of the tile was painted")
    }

    @Test("Each tier paints its own colour")
    func tiersAreVisuallyDistinct() {
        let tiers: [DailyBadgeTier] = [.bronze, .silver, .gold]
        var renders: [DailyBadgeTier: RenderedView] = [:]

        for tier in tiers {
            guard let rendered = VisualProbe.require(
                MiniBadgeView(badge: VisualFixture.badge(tier: tier)),
                width: 120,
                height: 120,
                "\(tier) badge"
            ) else { return }
            renders[tier] = rendered

            // The tier's own tint has to be the colour that dominates the medal.
            #expect(
                rendered.contains(PixelColor(tier.tint), tolerance: 0.16, minimumCoverage: 0.04),
                "\(tier) badge does not show its tint"
            )
        }

        // And the three tiers must be told apart at a glance, not just in code.
        for (first, second) in [
            (DailyBadgeTier.bronze, DailyBadgeTier.silver),
            (.silver, .gold),
            (.bronze, .gold)
        ] {
            guard let a = renders[first], let b = renders[second] else { continue }
            #expect(
                a.difference(from: b) > 0.02,
                "\(first) and \(second) badges look nearly identical"
            )
        }
    }

    @Test("Tier tints get brighter as the tier rises")
    func higherTiersReadAsBrighter() {
        // Bronze through gold should feel like a progression, not three
        // arbitrary colours.
        let bronze = PixelColor(DailyBadgeTier.bronze.tint)
        let gold = PixelColor(DailyBadgeTier.gold.tint)

        #expect(gold.brightness > bronze.brightness)
        #expect(PixelColor(DailyBadgeTier.silver.tint).saturation < gold.saturation)
    }

    @Test("A badge shows what the day was spent training")
    func badgeSymbolFollowsTheWork() {
        // The gallery is a record of the work, so two different kinds of day
        // must not be remembered by the same mark — and that now includes a leg
        // day, which has no trunk job to be named after.
        let symbols = CatalogSection.all.map {
            VisualFixture.badge(tier: .gold, section: $0).symbol
        }
        #expect(Set(symbols).count == symbols.count, "sections share a badge symbol: \(symbols)")

        // A day that covered every job earns a mark none of them can produce.
        let complete = VisualFixture.badge(
            tier: .gold, section: .pattern(.antiExtension), patterns: Set(CorePattern.allCases)
        )
        #expect(complete.isComplete)
        #expect(!symbols.contains(complete.symbol))

        guard
            let gainage = VisualProbe.require(
                MiniBadgeView(badge: VisualFixture.badge(tier: .gold, section: .pattern(.antiExtension))),
                width: 120, height: 120, "anti-extension badge"
            ),
            let lateral = VisualProbe.require(
                MiniBadgeView(badge: VisualFixture.badge(tier: .gold, section: .pattern(.antiLateralFlexion))),
                width: 120, height: 120, "anti-lateral badge"
            )
        else { return }

        let left = gainage.cropped(x: 34, y: 6, width: 52, height: 52)
        let right = lateral.cropped(x: 34, y: 6, width: 52, height: 52)
        #expect(left.difference(from: right) > 0.01, "two badge symbols rasterise the same")
    }

    @Test("The gallery grows with the number of badges")
    func galleryReflectsItsContents() {
        let single = [VisualFixture.badge(tier: .gold, offset: 0)]
        let many = (0..<12).map { VisualFixture.badge(tier: .silver, offset: -$0) }

        guard
            let one = VisualProbe.require(
                BadgeGallery(badges: single), width: 340, height: 300, "one badge"
            ),
            let dozen = VisualProbe.require(
                BadgeGallery(badges: many), width: 340, height: 300, "twelve badges"
            )
        else { return }

        #expect(dozen.paintedRatio > one.paintedRatio, "more badges did not paint more pixels")
        #expect(dozen.difference(from: one) > 0.01)
    }

    @Test("An empty gallery shows the placeholder instead of nothing")
    func emptyGalleryStillCommunicates() {
        guard let rendered = VisualProbe.require(
            BadgeGallery(badges: []), width: 340, height: 300, "empty gallery"
        ) else { return }

        #expect(!rendered.isBlank, "an empty collection rendered a blank card")
        #expect(rendered.paintedRatio > 0.4, "the placeholder barely covers the card")
    }

    @Test("The gallery renders in dark mode too")
    func galleryWorksInDarkMode() {
        let badges = (0..<6).map { VisualFixture.badge(tier: .gold, offset: -$0) }

        guard
            let light = VisualProbe.require(
                BadgeGallery(badges: badges), width: 340, height: 300,
                colorScheme: .light, "light gallery"
            ),
            let dark = VisualProbe.require(
                BadgeGallery(badges: badges), width: 340, height: 300,
                colorScheme: .dark, "dark gallery"
            )
        else { return }

        #expect(!dark.isBlank)
        // The medals themselves keep their tint in both appearances, so the
        // badge stays recognisable when the surrounding card inverts.
        let gold = PixelColor(DailyBadgeTier.gold.tint)
        #expect(light.contains(gold, tolerance: 0.18, minimumCoverage: 0.01))
        #expect(dark.contains(gold, tolerance: 0.18, minimumCoverage: 0.01))
    }

    @Test("The stats strip renders all three figures")
    func statsStripShowsEveryMetric() {
        let summary = RewardsSummary(
            currentStreak: 7,
            longestStreak: 21,
            todayBadge: nil,
            dailyBadges: (0..<9).map { VisualFixture.badge(tier: .bronze, offset: -$0) },
            weeklyBalance: VisualFixture.challenge(current: 2, target: 3),
            monthlyChallenge: VisualFixture.challenge(current: 6, target: 12),
            annualChallenge: VisualFixture.challenge(current: 40, target: 100)
        )

        guard let rendered = VisualProbe.require(
            RewardStatsStrip(summary: summary), width: 340, height: 120, "stats strip"
        ) else { return }

        #expect(!rendered.isBlank)
        // Three columns of content mean the middle third cannot be empty.
        let middle = rendered.cropped(
            x: rendered.width / 3, y: 0,
            width: rendered.width / 3, height: rendered.height
        )
        #expect(middle.paintedRatio > 0.3, "the middle metric is missing")
    }

    // MARK: - Awards

    @Test("An earned award and a locked one do not look alike")
    func achievementTilesShowTheirState() {
        guard
            let earned = VisualProbe.require(
                AchievementTile(
                    achievement: VisualFixture.achievement(current: 7, target: 7, unlocked: true)
                ),
                width: 110, height: 110, "earned tile"
            ),
            let locked = VisualProbe.require(
                AchievementTile(achievement: VisualFixture.achievement(current: 2, target: 7)),
                width: 110, height: 110, "locked tile"
            )
        else { return }

        #expect(!earned.isBlank)
        #expect(earned.difference(from: locked) > 0.02, "an earned award looks like a locked one")
        #expect(
            earned.contains(
                PixelColor(AchievementFamily.regularity.tint), tolerance: 0.18, minimumCoverage: 0.03
            ),
            "an earned award does not carry its family's colour"
        )
    }

    @Test("A locked award shows how close it is")
    func lockedTilesShowTheirProgress() {
        let tint = PixelColor(AchievementFamily.volume.tint)
        var painted: [Int] = []

        for current in [0, 25, 50, 95] {
            guard let rendered = VisualProbe.require(
                AchievementTile(
                    achievement: VisualFixture.achievement(family: .volume, current: current, target: 100)
                ),
                width: 110, height: 110, "ring at \(current) of 100"
            ) else { return }
            painted.append(rendered.count(of: tint, tolerance: 0.2))
        }

        // A grey disc with no ring is a dead end; every rung has to be visible.
        for index in 1..<painted.count {
            #expect(
                painted[index] > painted[index - 1],
                "progress \(index) of the locked ring is invisible: \(painted)"
            )
        }
    }

    @Test("Each family of awards paints its own colour")
    func achievementFamiliesAreDistinct() {
        var renders: [AchievementFamily: RenderedView] = [:]

        for family in AchievementFamily.allCases {
            // Over white: the medal is a gradient that fades to half opacity,
            // and against nothing at all a faded tint still reads as the pure
            // colour once the alpha is divided back out.
            guard let rendered = VisualProbe.require(
                AchievementTile(
                    achievement: VisualFixture.achievement(family: family, current: 5, target: 5, unlocked: true)
                )
                .background(Color.white),
                width: 110, height: 110, "\(family.rawValue) tile"
            ) else { return }
            renders[family] = rendered
            #expect(
                rendered.contains(PixelColor(family.tint), tolerance: 0.25, minimumCoverage: 0.01),
                "\(family.rawValue) does not show its tint"
            )
        }

        // And the six read as six, not as one palette with labels.
        for (first, second) in [
            (AchievementFamily.regularity, AchievementFamily.coverage),
            (.volume, .intensity),
            (.mastery, .ritual)
        ] {
            guard let left = renders[first], let right = renders[second] else { continue }
            #expect(left.difference(from: right) > 0.01, "\(first.rawValue) and \(second.rawValue) look alike")
        }
    }

    @Test("The wide award row carries its progress figure")
    func achievementRowIsLegible() {
        // Over white, because the row's disc is the same colour at low opacity
        // and a transparency test would count it as part of the arc.
        guard
            let early = VisualProbe.require(
                AchievementRow(achievement: VisualFixture.achievement(current: 1, target: 30))
                    .background(Color.white),
                width: 300, height: 60, "early award"
            ),
            let close = VisualProbe.require(
                AchievementRow(achievement: VisualFixture.achievement(current: 28, target: 30))
                    .background(Color.white),
                width: 300, height: 60, "nearly finished award"
            )
        else { return }

        #expect(!early.isBlank)
        let tint = PixelColor(AchievementFamily.regularity.tint)
        #expect(
            close.count(of: tint, tolerance: 0.2) > early.count(of: tint, tolerance: 0.2),
            "the row does not show how far along it is"
        )
    }

    // MARK: - Streak

    @Test("A series at risk does not look like a safe one")
    func streakCardShowsItsState() {
        guard
            let secured = VisualProbe.require(
                StreakCard(streak: VisualFixture.streak(current: 12, isSecuredToday: true)),
                width: 340, height: 210, "secured streak"
            ),
            let atRisk = VisualProbe.require(
                StreakCard(streak: VisualFixture.streak(current: 12, isSecuredToday: false)),
                width: 340, height: 210, "streak at risk"
            )
        else { return }

        #expect(!secured.isBlank)
        #expect(secured.difference(from: atRisk) > 0.004, "a series at risk looks identical to a safe one")
        #expect(secured.contains(PixelColor(Color.haraCoral), tolerance: 0.2, minimumCoverage: 0.005))
        #expect(atRisk.contains(PixelColor(Color.haraOrange), tolerance: 0.2, minimumCoverage: 0.005))
    }

    @Test("A streak that has never started still fills its card")
    func idleStreakCardStillCommunicates() {
        guard let rendered = VisualProbe.require(
            StreakCard(streak: .idle), width: 340, height: 210, "idle streak"
        ) else { return }

        #expect(!rendered.isBlank)
        #expect(rendered.paintedRatio > 0.5, "the card is mostly empty with no series")
    }

    // MARK: - Goals

    @Test("A fuller progress track paints more of itself")
    func progressTrackGrowsWithProgress() {
        let tint = PixelColor(Color.haraMint)
        var painted: [Int] = []

        // Drawn over white on purpose: the empty part of the track is the same
        // colour at low opacity, and a transparency test would count both.
        for progress in [0.0, 0.25, 0.6, 1.0] {
            guard let rendered = VisualProbe.require(
                ProgressTrack(progress: progress, tint: .haraMint).background(Color.white),
                width: 200, height: 12, "track at \(progress)"
            ) else { return }
            painted.append(rendered.count(of: tint, tolerance: 0.25))
        }

        for index in 1..<painted.count {
            #expect(painted[index] > painted[index - 1], "the track does not grow: \(painted)")
        }
    }

    @Test("Every horizon gets its own colour")
    func goalsSectionShowsEveryHorizon() {
        // One card per render rather than the whole stack: four cards do not
        // fit a fixed canvas, and a clipped fourth card would fail this for a
        // reason that has nothing to do with the colours.
        let horizons: [(period: ChallengePeriod, tint: Color)] = [
            (.day, .haraCoral),
            (.week, .haraMint),
            (.month, .haraOrange),
            (.year, .haraBlue)
        ]
        var renders: [RenderedView] = []

        for horizon in horizons {
            let goal = VisualFixture.goal(
                title: "Objectif", period: horizon.period, unit: .activeDays, current: 6, target: 12
            )
            guard let rendered = VisualProbe.require(
                GoalsSection(goals: [goal]), width: 340, height: 220, "\(horizon.period.rawValue) goal"
            ) else { return }

            #expect(!rendered.isBlank)
            #expect(
                rendered.contains(PixelColor(horizon.tint), tolerance: 0.2, minimumCoverage: 0.004),
                "the \(horizon.period.rawValue) horizon does not carry its colour"
            )
            renders.append(rendered)
        }

        for index in renders.indices.dropFirst() {
            #expect(
                renders[index].difference(from: renders[index - 1]) > 0.002,
                "two horizons rasterise the same"
            )
        }
    }

    @Test("An empty goals section still says what to do")
    func emptyGoalsSectionCommunicates() {
        guard let rendered = VisualProbe.require(
            GoalsSection(goals: []), width: 340, height: 280, "empty goals"
        ) else { return }

        #expect(!rendered.isBlank)
        #expect(rendered.paintedRatio > 0.4, "the placeholder barely covers the card")
    }
}

// MARK: - Fixtures

/// Kept here rather than in `VisualTestSupport` so the rewards surface can grow
/// its own fixtures without every other visual suite recompiling around them.
extension VisualFixture {
    static func achievement(
        id: String = "fixture-award",
        family: AchievementFamily = .regularity,
        current: Int,
        target: Int,
        unit: ChallengeUnit = .activeDays,
        unlocked: Bool = false
    ) -> Achievement {
        Achievement(
            id: id,
            title: "Semaine pleine",
            detail: "Sept jours actifs d’affilée.",
            symbol: "flame.fill",
            family: family,
            unit: unit,
            currentValue: current,
            targetValue: target,
            unlockedAt: unlocked ? day(offset: -1) : nil
        )
    }

    static func streak(
        current: Int,
        longest: Int = 21,
        restDaysUsed: Int = 0,
        restDaysEarned: Int = 2,
        isSecuredToday: Bool
    ) -> StreakStatus {
        StreakStatus(
            current: current,
            longest: longest,
            restDaysUsed: restDaysUsed,
            restDaysEarned: restDaysEarned,
            isSecuredToday: isSecuredToday
        )
    }

    static func goal(
        title: String,
        period: ChallengePeriod,
        unit: ChallengeUnit,
        current: Int,
        target: Int
    ) -> ChallengeProgress {
        ChallengeProgress(
            id: "goal-\(period.rawValue)",
            title: title,
            detail: "Un objectif calé sur votre rythme.",
            period: period,
            unit: unit,
            currentValue: current,
            targetValue: target,
            startDate: day(offset: -3),
            endDate: day(offset: 3),
            symbol: "target"
        )
    }
}
