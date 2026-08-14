import CoreGraphics
import SwiftUI
import Testing
import UIKit
@testable import FastAbs

/// A colour sampled from, or compared against, a rendered view.
struct PixelColor: Equatable, CustomStringConvertible {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    @MainActor
    init(_ color: Color) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }

    /// Straight-line distance in RGB, ignoring alpha, in `0...1`.
    func distance(to other: PixelColor) -> Double {
        let deltaRed = red - other.red
        let deltaGreen = green - other.green
        let deltaBlue = blue - other.blue
        return ((deltaRed * deltaRed + deltaGreen * deltaGreen + deltaBlue * deltaBlue) / 3).squareRoot()
    }

    var brightness: Double { (red * 0.299 + green * 0.587 + blue * 0.114) }

    /// How far the colour is from grey. Useful for asserting that something is
    /// tinted at all without pinning an exact shade.
    var saturation: Double {
        let highest = max(red, max(green, blue))
        let lowest = min(red, min(green, blue))
        return highest <= 0 ? 0 : (highest - lowest) / highest
    }

    var description: String {
        String(format: "rgba(%.3f, %.3f, %.3f, %.3f)", red, green, blue, alpha)
    }
}

/// A SwiftUI view turned into pixels so its appearance can be asserted on.
///
/// This deliberately avoids stored reference images: those break on every
/// Xcode and iOS update and turn into noise nobody reads. Instead each test
/// states the property it actually cares about — a tier colour is present, a
/// locked badge looks different from an unlocked one, a fuller ring paints more
/// pixels — which stays true across rendering changes.
struct RenderedView {
    let width: Int
    let height: Int
    /// Row-major RGBA, premultiplied alpha undone on read.
    private let samples: [UInt8]

    init(width: Int, height: Int, samples: [UInt8]) {
        self.width = width
        self.height = height
        self.samples = samples
    }

    var pixelCount: Int { width * height }

    func pixel(x: Int, y: Int) -> PixelColor {
        guard x >= 0, y >= 0, x < width, y < height else {
            return PixelColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
        let offset = (y * width + x) * 4
        let alpha = Double(samples[offset + 3]) / 255
        guard alpha > 0 else { return PixelColor(red: 0, green: 0, blue: 0, alpha: 0) }
        return PixelColor(
            red: Double(samples[offset]) / 255 / alpha,
            green: Double(samples[offset + 1]) / 255 / alpha,
            blue: Double(samples[offset + 2]) / 255 / alpha,
            alpha: alpha
        )
    }

    var pixels: [PixelColor] {
        (0..<height).flatMap { y in (0..<width).map { x in pixel(x: x, y: y) } }
    }

    /// Fraction of visible pixels within `tolerance` of `color`.
    func coverage(of color: PixelColor, tolerance: Double = 0.1) -> Double {
        let visible = pixels.filter { $0.alpha > 0.05 }
        guard !visible.isEmpty else { return 0 }
        let matches = visible.count { $0.distance(to: color) <= tolerance }
        return Double(matches) / Double(visible.count)
    }

    func contains(_ color: PixelColor, tolerance: Double = 0.1, minimumCoverage: Double = 0.005) -> Bool {
        coverage(of: color, tolerance: tolerance) >= minimumCoverage
    }

    /// Fraction of the canvas that was actually painted.
    var paintedRatio: Double {
        guard pixelCount > 0 else { return 0 }
        return Double(pixels.count { $0.alpha > 0.05 }) / Double(pixelCount)
    }

    var isBlank: Bool { paintedRatio < 0.02 }

    var averageColor: PixelColor {
        let visible = pixels.filter { $0.alpha > 0.05 }
        guard !visible.isEmpty else { return PixelColor(red: 0, green: 0, blue: 0, alpha: 0) }
        let count = Double(visible.count)
        return PixelColor(
            red: visible.reduce(0) { $0 + $1.red } / count,
            green: visible.reduce(0) { $0 + $1.green } / count,
            blue: visible.reduce(0) { $0 + $1.blue } / count,
            alpha: 1
        )
    }

    /// Mean per-pixel colour distance from another render of the same size.
    func difference(from other: RenderedView) -> Double {
        guard width == other.width, height == other.height, pixelCount > 0 else { return 1 }
        let total = zip(pixels, other.pixels).reduce(0.0) { $0 + $1.0.distance(to: $1.1) }
        return total / Double(pixelCount)
    }

    /// Number of visible pixels whose colour is close to `color`.
    func count(of color: PixelColor, tolerance: Double = 0.1) -> Int {
        pixels.count { $0.alpha > 0.05 && $0.distance(to: color) <= tolerance }
    }

    func cropped(x: Int, y: Int, width cropWidth: Int, height cropHeight: Int) -> RenderedView {
        var cropped: [UInt8] = []
        cropped.reserveCapacity(cropWidth * cropHeight * 4)
        for row in y..<(y + cropHeight) {
            for column in x..<(x + cropWidth) {
                let pixel = self.pixel(x: column, y: row)
                let alpha = pixel.alpha
                cropped.append(UInt8((pixel.red * alpha * 255).rounded()))
                cropped.append(UInt8((pixel.green * alpha * 255).rounded()))
                cropped.append(UInt8((pixel.blue * alpha * 255).rounded()))
                cropped.append(UInt8((alpha * 255).rounded()))
            }
        }
        return RenderedView(width: cropWidth, height: cropHeight, samples: cropped)
    }
}

@MainActor
enum VisualProbe {
    /// Renders a view at a fixed size so tests compare like with like.
    ///
    /// Returns `nil` only if the platform refuses to rasterise, which the
    /// callers surface as a failure rather than silently passing.
    static func render(
        _ view: some View,
        width: CGFloat = 320,
        height: CGFloat = 240,
        colorScheme: ColorScheme = .light
    ) -> RenderedView? {
        let content = view
            .frame(width: width, height: height)
            .environment(\.colorScheme, colorScheme)
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .environment(\.calendar, Calendar(identifier: .gregorian))
            .environment(\.timeZone, TimeZone(identifier: "UTC") ?? .current)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = false
        guard let image = renderer.cgImage else { return nil }

        let pixelWidth = image.width
        let pixelHeight = image.height
        var samples = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)

        guard let context = CGContext(
            data: &samples,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        return RenderedView(width: pixelWidth, height: pixelHeight, samples: samples)
    }

    /// Renders and fails the test if rasterisation was impossible, so a broken
    /// harness can never look like a passing suite.
    static func require(
        _ view: some View,
        width: CGFloat = 320,
        height: CGFloat = 240,
        colorScheme: ColorScheme = .light,
        _ label: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> RenderedView? {
        let rendered = render(view, width: width, height: height, colorScheme: colorScheme)
        if rendered == nil {
            Issue.record("could not rasterise \(label)", sourceLocation: sourceLocation)
        }
        return rendered
    }
}

// MARK: - Fixtures

enum VisualFixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    static let referenceDate = Date(timeIntervalSince1970: 1_767_225_600)

    static func day(offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: referenceDate) ?? referenceDate
    }

    static func badge(
        tier: DailyBadgeTier,
        offset: Int = 0,
        activeSeconds: Int = 600,
        pattern: CorePattern = .antiExtension,
        patterns: Set<CorePattern>? = nil,
        exerciseIDs: [String] = ["forearm-plank"]
    ) -> DailyBadge {
        DailyBadge(
            day: day(offset: offset),
            activeSeconds: activeSeconds,
            sessionCount: 1,
            tier: tier,
            pattern: pattern,
            patterns: patterns ?? [pattern],
            exerciseIDs: exerciseIDs
        )
    }

    static func challenge(
        current: Int,
        target: Int,
        unit: ChallengeUnit = .activeDays,
        title: String = "Mois régulier"
    ) -> ChallengeProgress {
        ChallengeProgress(
            id: "fixture-\(current)-\(target)",
            title: title,
            detail: "Bougez souvent, même quelques minutes.",
            period: .month,
            unit: unit,
            currentValue: current,
            targetValue: target,
            startDate: day(offset: -20),
            endDate: day(offset: 10),
            symbol: "calendar.badge.checkmark"
        )
    }

    static func overview(
        currentStreak: Int = 7,
        longestStreak: Int = 14,
        totalActiveSeconds: Int = 9_000,
        currentWeekSeconds: Int = 2_400,
        previousWeekSeconds: Int = 1_800
    ) -> WorkoutHistoryOverview {
        WorkoutHistoryOverview(
            totalSessions: 21,
            totalActiveSeconds: totalActiveSeconds,
            totalCalories: 1_400,
            activeDays: 18,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            currentWeekSeconds: currentWeekSeconds,
            previousWeekSeconds: previousWeekSeconds,
            currentMonthSessions: 12
        )
    }

    /// `activeSecondsByOffset` maps a day offset to that day's active seconds;
    /// missing days are rendered as rest days.
    static func days(count: Int, activeSecondsByOffset: [Int: Int] = [:]) -> [WorkoutHistoryDay] {
        (0..<count).map { index in
            let seconds = activeSecondsByOffset[index] ?? 0
            return WorkoutHistoryDay(
                date: day(offset: index - count + 1),
                sessionCount: seconds > 0 ? 1 : 0,
                activeSeconds: seconds,
                calories: seconds / 10
            )
        }
    }

    static func focus() -> [WorkoutFocusBreakdown] {
        [
            WorkoutFocusBreakdown(zone: .fullCore, sessionCount: 9),
            WorkoutFocusBreakdown(zone: .obliques, sessionCount: 5),
            WorkoutFocusBreakdown(zone: .lowerAbs, sessionCount: 3),
            WorkoutFocusBreakdown(zone: .deepCore, sessionCount: 2)
        ]
    }
}
