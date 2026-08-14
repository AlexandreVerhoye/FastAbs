import SwiftUI

/// How hard a muscle is working, as a colour.
///
/// A resting group is exactly the body's own white so it vanishes into the
/// silhouette; effort brings it up through coral to a deep red at peak
/// contraction.
enum MuscleHeat {
    static let resting = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let working = Color(red: 1.0, green: 0.36, blue: 0.31)
    static let peak = Color(red: 0.84, green: 0.05, blue: 0.12)

    static func color(for intensity: Float) -> Color {
        let amount = Double(min(max(intensity.isFinite ? intensity : 0, 0), 1))
        return amount <= 0.5
            ? blend(resting, working, amount * 2)
            : blend(working, peak, (amount - 0.5) * 2)
    }

    /// A working muscle also gains a little opacity, so the very first hint of
    /// effort reads as a tint rather than a hard edge appearing.
    static func opacity(for intensity: Float) -> Double {
        let amount = Double(min(max(intensity.isFinite ? intensity : 0, 0), 1))
        return 0.16 + 0.84 * min(1, amount * 2.2)
    }

    private static func blend(_ from: Color, _ to: Color, _ amount: Double) -> Color {
        let start = components(from)
        let end = components(to)
        let t = min(max(amount, 0), 1)
        return Color(
            red: start.red + (end.red - start.red) * t,
            green: start.green + (end.green - start.green) * t,
            blue: start.blue + (end.blue - start.blue) * t
        )
    }

    private static func components(_ color: Color) -> (red: Double, green: Double, blue: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }
}

/// Every measurement the figure is drawn from, in the same world units as the
/// skeleton, so the whole athlete scales as one.
///
/// Widths follow adult proportions — an upper arm is roughly a third as thick
/// as it is long — which is what keeps the silhouette from reading as either a
/// stick or a balloon.
enum FigureMetrics {
    // Limbs taper: a shoulder is thicker than an elbow, a hip than a knee.
    // Drawing every segment at one width is what made the figure read as tubing.
    static let upperArmTop: CGFloat = 0.125
    static let upperArmBottom: CGFloat = 0.098
    static let forearmTop: CGFloat = 0.094
    static let forearmBottom: CGFloat = 0.072
    static let thighTop: CGFloat = 0.192
    static let thighBottom: CGFloat = 0.136
    static let shinTop: CGFloat = 0.128
    static let shinBottom: CGFloat = 0.082
    static let neck: CGFloat = 0.13

    static let handWidth: CGFloat = 0.088
    static let handLength: CGFloat = 0.075
    static let footHeel: CGFloat = 0.098
    static let footToe: CGFloat = 0.062

    /// The gap punched between a part and whatever it overlaps. Without it the
    /// whole figure merges into one white mass.
    static let separation: CGFloat = 0.016

    static let headRadius: CGFloat = 0.116
    /// How far along the chest-to-head line the skull is actually drawn.
    static let headSeating: CGFloat = 0.82

    /// Seen from the side, the trunk's on-screen width is the body's depth.
    /// Using the shoulder span here drew a slab twice as wide as a person.
    static let chestHalfDepth: CGFloat = 0.158
    static let waistHalfDepth: CGFloat = 0.108
    static let seatHalfDepth: CGFloat = 0.152
    /// How far the shoulder line and the seat bulge past their joints.
    static let shoulderCrown: CGFloat = 0.14
    static let seatCrown: CGFloat = 0.12

    /// Abdominal bands run wider than the trunk so clipping gives them the
    /// body's own edge; the obliques sit out on the flanks.
    static let bandHalfWidth: CGFloat = 0.125
    static let obliqueOffset: CGFloat = 0.15
    static let obliqueWidth: CGFloat = 0.075

    /// How far the trunk runs past the hip and shoulder joints.
    static let seatOverhang: CGFloat = 0.06
    static let chestOverhang: CGFloat = 0.02

    /// Half the widest the athlete ever gets, used to pad the framing.
    static let silhouettePadding: CGFloat = 0.22
}

/// The near-to-far shading that gives a flat figure its depth.
enum FigureShading {
    static let near = Color(red: 0.97, green: 0.97, blue: 0.98)
    static let far = Color(red: 0.87, green: 0.88, blue: 0.91)

    /// `depth` is the joint's sideways position: positive is nearer the viewer.
    /// The spread is deliberately narrow — enough to tell a far limb from a
    /// near one, not so much that the athlete looks smudged.
    static func body(atDepth depth: CGFloat) -> Color {
        let t = min(max((depth + 0.3) / 0.6, 0), 1)
        return Color(
            red: 0.87 + (0.97 - 0.87) * t,
            green: 0.88 + (0.97 - 0.88) * t,
            blue: 0.91 + (0.98 - 0.91) * t
        )
    }
}
