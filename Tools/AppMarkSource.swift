// Source of the app mark, kept out of the build.
//
// The icon ships as a PNG in the asset catalog. This is the drawing that
// produced it: paste it into a test with an `ImageRenderer` at 1024 x 1024 to
// regenerate, rather than reverse-engineering the artwork later.

import SwiftUI

/// A plumb line: a taut vertical cord ending in a weight.
///
/// The name comes from *à plomb* — the mason's plumb line, the oldest tool
/// there is for finding true vertical. It is the same idea as a strong trunk,
/// it draws as pure geometry rather than as an illustration of a body, and it
/// is unmistakable at 40 points.
struct AppMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let centre = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.11, green: 0.10, blue: 0.24),
                        Color(red: 0.04, green: 0.04, blue: 0.09)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // A single off-centre glow keeps the field from reading as flat
                // fill without adding any ornament.
                Circle()
                    .fill(Color(red: 1, green: 0.32, blue: 0.25).opacity(0.34))
                    .frame(width: side * 0.66)
                    .blur(radius: side * 0.3)
                    .offset(x: side * 0.2, y: -side * 0.34)

                Canvas { context, size in
                    let unit = min(size.width, size.height)
                    let top = CGPoint(x: centre.x, y: unit * 0.235)
                    let bob = CGPoint(x: centre.x, y: unit * 0.585)

                    // The cord.
                    var cord = Path()
                    cord.move(to: top)
                    cord.addLine(to: CGPoint(x: centre.x, y: bob.y - unit * 0.035))
                    context.stroke(
                        cord,
                        with: .color(.white.opacity(0.92)),
                        style: StrokeStyle(lineWidth: unit * 0.028, lineCap: .round)
                    )

                    // The crossbar it hangs from.
                    var beam = Path()
                    beam.move(to: CGPoint(x: centre.x - unit * 0.165, y: unit * 0.235))
                    beam.addLine(to: CGPoint(x: centre.x + unit * 0.165, y: unit * 0.235))
                    context.stroke(
                        beam,
                        with: .color(.white.opacity(0.92)),
                        style: StrokeStyle(lineWidth: unit * 0.028, lineCap: .round)
                    )

                    // The weight: a plumb bob, drawn as a tapered spearhead.
                    let halfWidth = unit * 0.105
                    let shoulder = bob.y - unit * 0.03
                    var weight = Path()
                    weight.move(to: CGPoint(x: centre.x, y: bob.y - unit * 0.115))
                    weight.addQuadCurve(
                        to: CGPoint(x: centre.x + halfWidth, y: shoulder),
                        control: CGPoint(x: centre.x + halfWidth * 0.72, y: bob.y - unit * 0.1)
                    )
                    weight.addQuadCurve(
                        to: CGPoint(x: centre.x, y: bob.y + unit * 0.175),
                        control: CGPoint(x: centre.x + halfWidth * 0.62, y: bob.y + unit * 0.07)
                    )
                    weight.addQuadCurve(
                        to: CGPoint(x: centre.x - halfWidth, y: shoulder),
                        control: CGPoint(x: centre.x - halfWidth * 0.62, y: bob.y + unit * 0.07)
                    )
                    weight.addQuadCurve(
                        to: CGPoint(x: centre.x, y: bob.y - unit * 0.115),
                        control: CGPoint(x: centre.x - halfWidth * 0.72, y: bob.y - unit * 0.1)
                    )
                    weight.closeSubpath()

                    context.fill(
                        weight,
                        with: .linearGradient(
                            Gradient(colors: [
                                Color(red: 1, green: 0.45, blue: 0.32),
                                Color(red: 0.93, green: 0.17, blue: 0.2)
                            ]),
                            startPoint: CGPoint(x: centre.x - halfWidth, y: shoulder),
                            endPoint: CGPoint(x: centre.x + halfWidth, y: bob.y + unit * 0.175)
                        )
                    )
                }
            }
        }
    }
}
