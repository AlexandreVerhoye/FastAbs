import SwiftUI

extension Color {
    static let haraCoral = Color(red: 1.00, green: 0.32, blue: 0.25)
    static let haraOrange = Color(red: 1.00, green: 0.57, blue: 0.18)
    static let haraIndigo = Color(red: 0.10, green: 0.08, blue: 0.31)
    static let haraNavy = Color(red: 0.035, green: 0.035, blue: 0.12)
    static let haraMint = Color(red: 0.25, green: 0.84, blue: 0.65)
    static let haraBlue = Color(red: 0.26, green: 0.55, blue: 1.00)
}

extension ShapeStyle where Self == LinearGradient {
    static var haraHero: LinearGradient {
        LinearGradient(
            colors: [.haraCoral, .haraOrange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var haraNight: LinearGradient {
        LinearGradient(
            colors: [.haraIndigo, .haraNavy],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 20, y: 8)
            )
    }
}

extension View {
    func glassCard() -> some View { modifier(GlassCardModifier()) }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct MetricPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.haraCoral)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

// MARK: - Tokens

/// Corner radii, spacing and type in one place.
///
/// Before this the app used eight different corner radii and wrote its fonts
/// out by hand at every call site, which is how a design drifts without anyone
/// deciding to change it.
enum Metric {
    /// Page gutter.
    static let gutter: CGFloat = 18
    /// Between two sections of a screen.
    static let section: CGFloat = 26
    /// Between rows inside one card.
    static let row: CGFloat = 12
    /// Inside a card.
    static let cardPadding: CGFloat = 16

    enum Radius {
        /// Pills, chips, small tiles.
        static let small: CGFloat = 14
        /// Cards.
        static let card: CGFloat = 24
        /// Hero surfaces and full-bleed panels.
        static let hero: CGFloat = 30
    }
}

extension Font {
    /// The one oversized numeral style, for a streak or a countdown.
    static let haraDisplay = Font.system(size: 42, weight: .bold, design: .rounded).monospacedDigit()
    static let haraHeroTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let haraCardTitle = Font.system(.title3, design: .rounded, weight: .bold)
    /// Small all-caps label above a block.
    static let haraEyebrow = Font.caption.weight(.bold)
    static let haraMetric = Font.headline.monospacedDigit()
}

// MARK: - Motion

/// The app's animation vocabulary, in one place.
///
/// Screens used to reach for `.snappy`, `.spring` with hand-picked constants,
/// or nothing at all, which is why the app read as a set of static pages with
/// the occasional twitch. A shared vocabulary is what makes motion feel like
/// one product rather than several.
enum Motion {
    /// A control answering a touch.
    static let tap = Animation.spring(response: 0.28, dampingFraction: 0.72)
    /// Content arriving or leaving.
    static let content = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// A list re-sorting itself under a filter.
    static let rearrange = Animation.spring(response: 0.5, dampingFraction: 0.9)
    /// A number moving to a new value.
    static let value = Animation.snappy(duration: 0.34)
    /// Something worth making a moment of.
    static let reveal = Animation.spring(response: 0.55, dampingFraction: 0.7)

    /// The same animation, flattened when the athlete has asked for less
    /// motion. Returned rather than decided at each call site, so a screen
    /// cannot forget to ask.
    static func honouring(_ reduceMotion: Bool, _ animation: Animation) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.16) : animation
    }
}

extension View {
    /// Fades and lifts content into place, and does neither when the athlete
    /// has asked for less motion.
    func appears(_ reduceMotion: Bool) -> some View {
        transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 10)),
                    removal: .opacity
                )
        )
    }
}

// MARK: - Controls

/// The app's primary action: full width, warm, and it answers to the touch.
struct HaraPrimaryButtonStyle: ButtonStyle {
    var tint: AnyShapeStyle = AnyShapeStyle(LinearGradient.haraHero)
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(tint, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

/// Quieter sibling of the primary button, for the second choice on a screen.
struct HaraSecondaryButtonStyle: ButtonStyle {
    var tint: Color = .haraCoral

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(tint.opacity(configuration.isPressed ? 0.2 : 0.12), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == HaraPrimaryButtonStyle {
    static var haraPrimary: HaraPrimaryButtonStyle { HaraPrimaryButtonStyle() }

    static func haraPrimary(tint: some ShapeStyle, foreground: Color = .white) -> HaraPrimaryButtonStyle {
        HaraPrimaryButtonStyle(tint: AnyShapeStyle(tint), foreground: foreground)
    }
}

extension ButtonStyle where Self == HaraSecondaryButtonStyle {
    static var haraSecondary: HaraSecondaryButtonStyle { HaraSecondaryButtonStyle() }
}

/// A tappable surface: a card, a tile, a hero action.
///
/// Every one of these used `.plain`, which gives a card no answer at all when a
/// finger lands on it — so a card read as decoration right up until it turned
/// out to have been a button. The movement is deliberately small; the point is
/// that the surface acknowledges the touch, not that it performs.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var card: CardButtonStyle { CardButtonStyle() }
}

/// A single-select capsule for a horizontal filter row.
struct FilterChip: View {
    let title: String
    var tint: Color = .haraCoral
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(
                    isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Color.secondary.opacity(0.12)),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension Bundle {
    /// The version as shipped, read from the bundle rather than typed into the
    /// settings screen — a number written by hand is a number that goes stale
    /// the first time it matters, which is when someone reports a bug against it.
    var versionSummary: String {
        let short = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
