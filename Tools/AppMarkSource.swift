import SwiftUI
// Source of the app mark, kept out of the build.
//
// The icon ships as a PNG in the asset catalog. This is the drawing that
// produced it: paste it into a test with an `ImageRenderer` at 1024 x 1024 to
// regenerate, rather than reverse-engineering the artwork later.

let ink = Color(red: 0.055, green: 0.05, blue: 0.115)
let inkTop = Color(red: 0.13, green: 0.11, blue: 0.26)
let ember = Color(red: 1.0, green: 0.36, blue: 0.27)
let deep = Color(red: 0.82, green: 0.10, blue: 0.17)

/// A disc cut by a single band, set below centre.
///
/// The obi sits at the hara, not at the waistline — the offset is the whole
/// mark. Reads as a belt, a horizon and a centre of gravity at once, and
/// survives being shrunk to a home-screen tile.
struct HaraMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(colors: [inkTop, ink], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, size in
                    let unit = min(size.width, size.height)
                    let centre = CGPoint(x: unit / 2, y: unit / 2)
                    let radius = unit * 0.29

                    var disc = Path()
                    disc.addEllipse(
                        in: CGRect(
                            x: centre.x - radius, y: centre.y - radius,
                            width: radius * 2, height: radius * 2
                        )
                    )

                    let bandHeight = unit * 0.088
                    let bandCentre = centre.y + radius * 0.34
                    var band = Path()
                    band.addRect(
                        CGRect(
                            x: centre.x - radius * 1.2,
                            y: bandCentre - bandHeight / 2,
                            width: radius * 2.4,
                            height: bandHeight
                        )
                    )

                    context.fill(
                        disc.subtracting(band),
                        with: .linearGradient(
                            Gradient(colors: [ember, deep]),
                            startPoint: CGPoint(x: centre.x - radius, y: centre.y - radius),
                            endPoint: CGPoint(x: centre.x + radius, y: centre.y + radius)
                        )
                    )
                }
                .frame(width: side, height: side)
            }
        }
    }
}

/// The keel line of a hull: what a boat is built around and what keeps it
/// upright. A long taper, weighted low.
struct KeelMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(colors: [inkTop, ink], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, size in
                    let unit = min(size.width, size.height)
                    let centre = unit / 2
                    var hull = Path()
                    hull.move(to: CGPoint(x: centre, y: unit * 0.19))
                    hull.addQuadCurve(
                        to: CGPoint(x: centre + unit * 0.17, y: unit * 0.62),
                        control: CGPoint(x: centre + unit * 0.2, y: unit * 0.36)
                    )
                    hull.addQuadCurve(
                        to: CGPoint(x: centre, y: unit * 0.82),
                        control: CGPoint(x: centre + unit * 0.12, y: unit * 0.76)
                    )
                    hull.addQuadCurve(
                        to: CGPoint(x: centre - unit * 0.17, y: unit * 0.62),
                        control: CGPoint(x: centre - unit * 0.12, y: unit * 0.76)
                    )
                    hull.addQuadCurve(
                        to: CGPoint(x: centre, y: unit * 0.19),
                        control: CGPoint(x: centre - unit * 0.2, y: unit * 0.36)
                    )
                    hull.closeSubpath()
                    context.fill(
                        hull,
                        with: .linearGradient(
                            Gradient(colors: [ember, deep]),
                            startPoint: CGPoint(x: centre - unit * 0.17, y: unit * 0.19),
                            endPoint: CGPoint(x: centre + unit * 0.17, y: unit * 0.82)
                        )
                    )
                }
                .frame(width: side, height: side)
            }
        }
    }
}
