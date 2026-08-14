import SwiftUI

extension Color {
    static let fastCoral = Color(red: 1.00, green: 0.32, blue: 0.25)
    static let fastOrange = Color(red: 1.00, green: 0.57, blue: 0.18)
    static let fastIndigo = Color(red: 0.10, green: 0.08, blue: 0.31)
    static let fastNavy = Color(red: 0.035, green: 0.035, blue: 0.12)
    static let fastMint = Color(red: 0.25, green: 0.84, blue: 0.65)
    static let fastBlue = Color(red: 0.26, green: 0.55, blue: 1.00)
}

extension ShapeStyle where Self == LinearGradient {
    static var fastHero: LinearGradient {
        LinearGradient(
            colors: [.fastCoral, .fastOrange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var fastNight: LinearGradient {
        LinearGradient(
            colors: [.fastIndigo, .fastNavy],
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
                .foregroundStyle(Color.fastCoral)
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
    static let fastDisplay = Font.system(size: 42, weight: .bold, design: .rounded).monospacedDigit()
    static let fastHeroTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let fastCardTitle = Font.system(.title3, design: .rounded, weight: .bold)
    /// Small all-caps label above a block.
    static let fastEyebrow = Font.caption.weight(.bold)
    static let fastMetric = Font.headline.monospacedDigit()
}

// MARK: - Controls

/// The app's primary action: full width, warm, and it answers to the touch.
struct FastPrimaryButtonStyle: ButtonStyle {
    var tint: AnyShapeStyle = AnyShapeStyle(LinearGradient.fastHero)
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
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Quieter sibling of the primary button, for the second choice on a screen.
struct FastSecondaryButtonStyle: ButtonStyle {
    var tint: Color = .fastCoral

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(tint.opacity(configuration.isPressed ? 0.2 : 0.12), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FastPrimaryButtonStyle {
    static var fastPrimary: FastPrimaryButtonStyle { FastPrimaryButtonStyle() }

    static func fastPrimary(tint: some ShapeStyle, foreground: Color = .white) -> FastPrimaryButtonStyle {
        FastPrimaryButtonStyle(tint: AnyShapeStyle(tint), foreground: foreground)
    }
}

extension ButtonStyle where Self == FastSecondaryButtonStyle {
    static var fastSecondary: FastSecondaryButtonStyle { FastSecondaryButtonStyle() }
}

/// A single-select capsule for a horizontal filter row.
struct FilterChip: View {
    let title: String
    var tint: Color = .fastCoral
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
