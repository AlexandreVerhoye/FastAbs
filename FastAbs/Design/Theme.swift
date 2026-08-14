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
