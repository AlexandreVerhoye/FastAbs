import Foundation
import Testing
@testable import FastAbs

/// The work the first screens pay for.
///
/// The app was slow to launch and slow to change tabs because several of these
/// were being recomputed per view init, per redraw, or per history record. They
/// are cached now; these are the numbers that made the difference, kept as a
/// regression guard rather than a benchmark.
@Suite("Startup cost")
struct StartupCostTests {
    @Test("Framing every movement stays cheap once warm")
    func figureBoundsAreCached() async {
        // Opening the Movements tab measures every motion it lists. Cold this
        // solved 48 poses per movement; the first call still does the work, so
        // what matters is that the second is free.
        let cold = await MainActor.run { measure { _ = warmAllBounds() } }
        let warm = await MainActor.run { measure { _ = warmAllBounds() } }

        #expect(warm < 0.001, "framing is being recomputed: \(warm)s")
        #expect(cold < 0.3, "first framing pass costs \(cold)s")
    }

    @Test("Building a workout is fast enough to feel instant")
    func planningIsFast() {
        let engine = WorkoutEngine()
        let elapsed = measure {
            for seed in 0..<20 {
                _ = engine.makePlan(preferences: TestSupport.preferences(), seed: UInt64(seed))
            }
        }
        // The customisation screen rebuilds a preview on every settings change.
        #expect(elapsed / 20 < 0.005, "a plan takes \(elapsed / 20)s to build")
    }

    @Test("Reading history back does not rescan the catalog")
    func historyLookupIsIndexed() {
        let plan = WorkoutEngine().makePlan(preferences: TestSupport.preferences(), seed: 3)
        let records = (0..<200).map { _ in WorkoutRecord(plan: plan) }

        let elapsed = measure {
            for record in records { _ = record.trainedZones }
        }
        #expect(elapsed < 0.03, "200 records take \(elapsed)s to read")
    }

    @MainActor
    private func warmAllBounds() -> Int {
        MotionSystemTests.allMotions.reduce(0) { total, motion in
            total + (FigureProjection.bounds(for: motion).width > 0 ? 1 : 0)
        }
    }

    private func measure(_ body: () -> Void) -> Double {
        let start = ProcessInfo.processInfo.systemUptime
        body()
        return ProcessInfo.processInfo.systemUptime - start
    }
}
