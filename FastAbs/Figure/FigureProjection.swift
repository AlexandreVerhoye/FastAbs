import CoreGraphics
import Foundation
import simd

/// One joint, flattened onto the card.
struct FigureJoint: Equatable {
    let point: CGPoint
    /// Sideways position in the original pose: positive is nearer the viewer.
    /// Used to decide what is drawn in front of what, and how brightly.
    let depth: CGFloat
}

/// A whole pose flattened and fitted to the space it will be drawn in.
struct FigureLayout: Equatable {
    let head: FigureJoint
    let neck: FigureJoint
    let chest: FigureJoint
    let pelvis: FigureJoint
    let leftShoulder: FigureJoint
    let rightShoulder: FigureJoint
    let leftElbow: FigureJoint
    let rightElbow: FigureJoint
    let leftHand: FigureJoint
    let rightHand: FigureJoint
    let leftHip: FigureJoint
    let rightHip: FigureJoint
    let leftKnee: FigureJoint
    let rightKnee: FigureJoint
    let leftAnkle: FigureJoint
    let rightAnkle: FigureJoint
    let leftToe: FigureJoint
    let rightToe: FigureJoint

    /// World units to points. Every stroke width is expressed in world units
    /// and multiplied by this, so the athlete never changes proportions.
    let scale: CGFloat

    /// Which way the athlete's belly faces on screen.
    let front: CGVector

    var joints: [FigureJoint] {
        [
            head, neck, chest, pelvis,
            leftShoulder, rightShoulder, leftElbow, rightElbow, leftHand, rightHand,
            leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle,
            leftToe, rightToe
        ]
    }
}

/// Flattens the 3D pose the choreography produces onto the card.
///
/// The view is very slightly three-quarter rather than dead-on side-on: a pure
/// side view would hide every sideways movement, so a bicycle crunch and a set
/// of scissors would look identical to a plain leg raise. Mixing a little of
/// the sideways axis into the horizontal keeps rotation and crossing legible
/// while still reading as a clean side profile.
enum FigureProjection {
    static let lateralShift: CGFloat = 0.3
    static let lateralRise: CGFloat = 0.05

    /// Flattens a direction rather than a point. The projection is linear, so a
    /// direction maps through the same weights without the origin.
    static func flattenDirection(_ direction: SIMD3<Float>) -> CGVector {
        let dx = CGFloat(direction.x) + CGFloat(direction.z) * lateralShift
        let dy = CGFloat(direction.y) + CGFloat(direction.z) * lateralRise
        let vector = CGVector(dx: dx, dy: -dy)
        let length = (vector.dx * vector.dx + vector.dy * vector.dy).squareRoot()
        guard length > 0.0001 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    static func flatten(_ position: SIMD3<Float>) -> CGPoint {
        let x = CGFloat(position.x) + CGFloat(position.z) * lateralShift
        let y = CGFloat(position.y) + CGFloat(position.z) * lateralRise
        // Screen coordinates grow downward, so the world's up becomes negative.
        return CGPoint(x: x, y: -y)
    }

    /// The area a whole movement sweeps through, in flattened world units.
    ///
    /// Framing is computed from the entire cycle rather than the current frame,
    /// otherwise the athlete would swell and shrink as the movement widened and
    /// narrowed — a pulse far more distracting than any pose.
    static func bounds(for motion: MotionKind, samples: Int = 48) -> CGRect {
        var minimum = CGPoint(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude)
        var maximum = CGPoint(x: -CGFloat.greatestFiniteMagnitude, y: -CGFloat.greatestFiniteMagnitude)

        for step in 0..<max(samples, 1) {
            let pose = MotionLibrary.pose(for: motion, phase: Float(step) / Float(max(samples, 1)))
            for position in pose.joints + [pose.leftToe, pose.rightToe] {
                let point = flatten(position)
                minimum.x = min(minimum.x, point.x)
                minimum.y = min(minimum.y, point.y)
                maximum.x = max(maximum.x, point.x)
                maximum.y = max(maximum.y, point.y)
            }
        }

        guard minimum.x < maximum.x else { return CGRect(x: -1, y: -1, width: 2, height: 2) }

        // Joints sit at the centre of the limbs drawn around them, so the
        // silhouette always spills past them.
        let padding = FigureMetrics.silhouettePadding
        let width: CGFloat = (maximum.x - minimum.x) + padding * 2
        let height: CGFloat = (maximum.y - minimum.y) + padding * 2
        return CGRect(x: minimum.x - padding, y: minimum.y - padding, width: width, height: height)
    }

    /// Fits a pose into `rect`, keeping the movement's own framing.
    static func layout(
        pose: BodyPose,
        within bounds: CGRect,
        in rect: CGRect
    ) -> FigureLayout {
        let scale: CGFloat
        if bounds.width > 0, bounds.height > 0, rect.width > 0, rect.height > 0 {
            scale = min(rect.width / bounds.width, rect.height / bounds.height)
        } else {
            scale = 1
        }

        let drawnSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let origin = CGPoint(
            x: rect.minX + (rect.width - drawnSize.width) / 2,
            y: rect.minY + (rect.height - drawnSize.height) / 2
        )

        func place(_ position: SIMD3<Float>) -> FigureJoint {
            let flat = flatten(position)
            return FigureJoint(
                point: CGPoint(
                    x: origin.x + (flat.x - bounds.minX) * scale,
                    y: origin.y + (flat.y - bounds.minY) * scale
                ),
                depth: CGFloat(position.z)
            )
        }

        return FigureLayout(
            head: place(pose.head),
            neck: place(pose.neck),
            chest: place(pose.chest),
            pelvis: place(pose.pelvis),
            leftShoulder: place(pose.leftShoulder),
            rightShoulder: place(pose.rightShoulder),
            leftElbow: place(pose.leftElbow),
            rightElbow: place(pose.rightElbow),
            leftHand: place(pose.leftHand),
            rightHand: place(pose.rightHand),
            leftHip: place(pose.leftHip),
            rightHip: place(pose.rightHip),
            leftKnee: place(pose.leftKnee),
            rightKnee: place(pose.rightKnee),
            leftAnkle: place(pose.leftAnkle),
            rightAnkle: place(pose.rightAnkle),
            leftToe: place(pose.leftToe),
            rightToe: place(pose.rightToe),
            scale: scale,
            front: flattenDirection(pose.front)
        )
    }
}

// MARK: - Geometry helpers

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }

    static func - (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        CGPoint(x: lhs.x - rhs.dx, y: lhs.y - rhs.dy)
    }

    func midpoint(to other: CGPoint) -> CGPoint {
        CGPoint(x: (x + other.x) / 2, y: (y + other.y) / 2)
    }

    /// Direction toward `other`, or `fallback` if the two coincide.
    func direction(to other: CGPoint, fallback: CGVector = CGVector(dx: 0, dy: -1)) -> CGVector {
        let vector = CGVector(dx: other.x - x, dy: other.y - y)
        let length = (vector.dx * vector.dx + vector.dy * vector.dy).squareRoot()
        guard length > 0.0001 else { return fallback }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }
}

extension CGVector {
    /// Turned a quarter turn, for stepping sideways off a limb.
    var perpendicular: CGVector { CGVector(dx: -dy, dy: dx) }

    static func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }
}
