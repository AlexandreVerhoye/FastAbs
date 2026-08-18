import Foundation
import SwiftUI
import Testing
@testable import Hara

/// Renders every movement across its cycle to a single image.
///
/// The automated invariants catch geometry that is provably wrong — a stretched
/// bone, a hole in the silhouette, a foot below the mat. They cannot catch a
/// pose that is legal and still unreadable, and that is what every complaint
/// about these animations has actually been. So the sheet exists: one picture,
/// every movement, six phases each, regenerated on demand and read.
///
/// Left enabled rather than marked manual: it costs well under a second, and a
/// review tool that has to be switched on is a review tool that rots. It prints
/// the path it wrote to.
@Suite("Motion contact sheet")
@MainActor
struct MotionContactSheet {
    static let phases: [Float] = [0, 0.17, 0.33, 0.5, 0.67, 0.83]

    struct Cell: View {
        let motion: MotionKind
        let phase: Float

        var body: some View {
            Canvas(rendersAsynchronously: false) { context, size in
                let layout = FigureProjection.layout(
                    pose: MotionLibrary.pose(for: motion, phase: phase),
                    within: FigureProjection.bounds(for: motion),
                    in: CGRect(origin: .zero, size: size)
                )
                FigureRenderer(
                    layout: layout,
                    activation: MuscleActivation.make(for: motion, phase: phase)
                ).draw(into: &context)
            }
        }
    }

    struct Row: View {
        let motion: MotionKind

        var body: some View {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(MotionLibrary.metadata(for: motion).title)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Text(motion.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(width: 130, alignment: .leading)
                .padding(.leading, 10)

                ForEach(MotionContactSheet.phases, id: \.self) { phase in
                    Cell(motion: motion, phase: phase)
                        .frame(width: 230, height: 260)
                }
            }
        }
    }

    @Test("Render every movement")
    func render() throws {
        // Split in halves: the whole catalog in one image overflows what PNG
        // encoding will take, and it failed by writing a truncated file rather
        // than by refusing.
        let motions = MotionKind.allCases.filter { $0 != .rest }
        let half = (motions.count + 1) / 2

        for (index, chunk) in [Array(motions.prefix(half)), Array(motions.dropFirst(half))].enumerated() {
            let sheet = VStack(spacing: 0) {
                ForEach(chunk, id: \.self) { Row(motion: $0) }
            }
            .background(Color.haraNavy)

            let renderer = ImageRenderer(content: sheet)
            renderer.scale = 1
            guard let data = renderer.uiImage?.pngData() else {
                Issue.record("sheet \(index + 1) did not rasterise")
                continue
            }

            let url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("hara-motions-\(index + 1).png")
            try data.write(to: url)
            print("CONTACT SHEET \(url.path)")
        }
    }
}
