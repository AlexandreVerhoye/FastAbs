import SwiftUI
import Testing
@testable import FastAbs

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

    @Test("Badge symbols differ across the styles a month can produce")
    func styleIndexChangesTheSymbol() {
        var seen: Set<String> = []
        for styleIndex in 0..<7 {
            seen.insert(VisualFixture.badge(tier: .gold, styleIndex: styleIndex).symbol)
        }
        #expect(seen.count == 7, "the badge rotation repeats itself: \(seen)")

        // Two different styles must also look different once drawn.
        guard
            let flame = VisualProbe.require(
                MiniBadgeView(badge: VisualFixture.badge(tier: .gold, styleIndex: 0)),
                width: 120, height: 120, "style 0"
            ),
            let crown = VisualProbe.require(
                MiniBadgeView(badge: VisualFixture.badge(tier: .gold, styleIndex: 6)),
                width: 120, height: 120, "style 6"
            )
        else { return }

        let flameFace = flame.cropped(x: 34, y: 6, width: 52, height: 52)
        let crownFace = crown.cropped(x: 34, y: 6, width: 52, height: 52)
        #expect(flameFace.difference(from: crownFace) > 0.01, "two badge styles rasterise the same")
    }

    @Test("The gallery grows with the number of badges")
    func galleryReflectsItsContents() {
        let single = [VisualFixture.badge(tier: .gold, offset: 0)]
        let many = (0..<12).map { VisualFixture.badge(tier: .silver, offset: -$0, styleIndex: $0) }

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
        let badges = (0..<6).map { VisualFixture.badge(tier: .gold, offset: -$0, styleIndex: $0) }

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
}
