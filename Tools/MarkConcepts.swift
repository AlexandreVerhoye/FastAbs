import SwiftUI
// Candidate app marks, kept out of the build.
//
// Paste one into a test with an `ImageRenderer` at 1024 x 1024 to produce the
// icon PNG for the asset catalog.

let ink = Color(red: 0.05, green: 0.05, blue: 0.11)
let ember = Color(red: 1.0, green: 0.34, blue: 0.26)
let deep = Color(red: 0.80, green: 0.11, blue: 0.18)

/// Concentric rings tightening onto a solid centre: density, focus, a core.
struct NoyauMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(colors: [ember, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(.white.opacity(0.9), lineWidth: side * 0.045)
                        .frame(width: side * (0.68 - CGFloat(ring) * 0.17))
                }
                Circle().fill(.white).frame(width: side * 0.14)
            }
        }
    }
}

/// A notch cut clean through a solid block — avoir du cran, and a notch gained.
struct CranMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(colors: [ink, Color(red: 0.12, green: 0.11, blue: 0.26)], startPoint: .top, endPoint: .bottom)
                Canvas { context, size in
                    let unit = min(size.width, size.height)
                    var block = Path()
                    let inset = unit * 0.22
                    block.addRoundedRect(
                        in: CGRect(x: inset, y: inset, width: unit - inset * 2, height: unit - inset * 2),
                        cornerSize: CGSize(width: unit * 0.09, height: unit * 0.09)
                    )
                    var notch = Path()
                    notch.move(to: CGPoint(x: unit * 0.5, y: inset - unit * 0.02))
                    notch.addLine(to: CGPoint(x: unit * 0.5 + unit * 0.15, y: unit * 0.5))
                    notch.addLine(to: CGPoint(x: unit * 0.5, y: unit - inset + unit * 0.02))
                    notch.addLine(to: CGPoint(x: unit * 0.5 - unit * 0.15, y: unit * 0.5))
                    notch.closeSubpath()

                    context.fill(
                        block.subtracting(notch),
                        with: .linearGradient(
                            Gradient(colors: [ember, deep]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: unit, y: unit)
                        )
                    )
                }
                .frame(width: side, height: side)
            }
        }
    }
}

/// A waist: two arcs pinching to a narrow centre, carved out of a solid field.
struct SocleMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(colors: [ink, Color(red: 0.14, green: 0.10, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, size in
                    let unit = min(size.width, size.height)
                    let centre = unit / 2
                    var shape = Path()
                    let top = unit * 0.2
                    let bottom = unit * 0.8
                    let wide = unit * 0.19
                    let waist = unit * 0.062

                    shape.move(to: CGPoint(x: centre - wide, y: top))
                    shape.addQuadCurve(
                        to: CGPoint(x: centre - wide, y: bottom),
                        control: CGPoint(x: centre - waist * 0.2, y: centre)
                    )
                    shape.addLine(to: CGPoint(x: centre + wide, y: bottom))
                    shape.addQuadCurve(
                        to: CGPoint(x: centre + wide, y: top),
                        control: CGPoint(x: centre + waist * 0.2, y: centre)
                    )
                    shape.closeSubpath()

                    context.fill(
                        shape,
                        with: .linearGradient(
                            Gradient(colors: [ember, deep]),
                            startPoint: CGPoint(x: centre - wide, y: top),
                            endPoint: CGPoint(x: centre + wide, y: bottom)
                        )
                    )
                }
                .frame(width: side, height: side)
            }
        }
    }
}
