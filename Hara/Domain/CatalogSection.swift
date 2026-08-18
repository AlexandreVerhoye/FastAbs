import SwiftUI

/// How the catalog is browsed and grouped.
///
/// Two grains on purpose. Trunk work reads best split by what it asks the trunk
/// to do — five different crunches are one section of the same idea, and that
/// is the axis a core session is balanced on. Everything else reads best split
/// by the part of the body it trains, because that is the question someone
/// browsing the legs is actually asking. And a movement that crosses the whole
/// athlete belongs to neither: filing a burpee under "anti-extension" is true
/// and useless.
///
/// The three cases partition the catalog exactly — every exercise lands in one
/// section and no exercise lands in two — which is what lets a picker built from
/// `all` be trusted to show everything.
enum CatalogSection: Hashable, Identifiable, Sendable {
    case pattern(CorePattern)
    case area(BodyArea)
    case wholeBody

    var id: String {
        switch self {
        case let .pattern(pattern): "pattern-\(pattern.rawValue)"
        case let .area(area): "area-\(area.rawValue)"
        case .wholeBody: "whole-body"
        }
    }

    /// Patterns first, then the parts of the body that answer no trunk
    /// question, then the compound movements.
    static let all: [CatalogSection] =
        CorePattern.allCases.map(CatalogSection.pattern)
        + [.area(.lowerBody), .area(.upperBody)]
        + [.wholeBody]

    var title: String {
        switch self {
        case let .pattern(pattern): pattern.title
        case let .area(area): area.title
        case .wholeBody: "Corps entier"
        }
    }

    var shortTitle: String {
        switch self {
        case let .pattern(pattern): pattern.shortTitle
        case let .area(area): area.shortTitle
        case .wholeBody: "Complet"
        }
    }

    var detail: String {
        switch self {
        case let .pattern(pattern): pattern.detail
        case let .area(area): area.detail
        case .wholeBody: "Un mouvement qui traverse tout le corps d’un bout à l’autre."
        }
    }

    var symbol: String {
        switch self {
        case let .pattern(pattern): pattern.symbol
        case let .area(area): area.symbol
        case .wholeBody: "figure.mixed.cardio"
        }
    }

    var color: Color {
        switch self {
        case let .pattern(pattern): pattern.color
        case let .area(area): area.color
        case .wholeBody: .haraOrange
        }
    }

    func contains(_ exercise: Exercise) -> Bool {
        switch self {
        case let .pattern(pattern): !exercise.isFullBody && exercise.pattern == pattern
        case let .area(area): !exercise.isFullBody && exercise.pattern == nil && exercise.primaryArea == area
        case .wholeBody: exercise.isFullBody
        }
    }

    /// The section a movement belongs to, which is exactly one of them.
    static func of(_ exercise: Exercise) -> CatalogSection {
        all.first { $0.contains(exercise) } ?? .wholeBody
    }

    /// Groups a list of movements, dropping the sections nothing landed in.
    static func grouping(_ exercises: [Exercise]) -> [(section: CatalogSection, exercises: [Exercise])] {
        var buckets: [CatalogSection: [Exercise]] = [:]
        for exercise in exercises {
            buckets[of(exercise), default: []].append(exercise)
        }
        return all.compactMap { section in
            guard let matching = buckets[section], !matching.isEmpty else { return nil }
            return (
                section,
                matching.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            )
        }
    }
}
