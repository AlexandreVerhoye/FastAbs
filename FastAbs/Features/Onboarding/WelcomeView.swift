import SwiftUI

struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let completion: () -> Void
    @State private var page = 0

    private let pages = [
        WelcomePage(
            symbol: "bolt.heart.fill",
            colors: [.fastCoral, .fastOrange],
            title: "Votre centre, chaque jour",
            message: "Une séance courte, complète et différente, pensée pour tenir dans votre quotidien."
        ),
        WelcomePage(
            symbol: "view.3d",
            colors: [.fastBlue, .purple],
            title: "Le mouvement sous tous les angles",
            message: "Chaque exercice est démontré par un coach 3D natif, avec des consignes simples et précises."
        ),
        WelcomePage(
            symbol: "medal.star.fill",
            colors: [.fastOrange, .yellow],
            title: "La régularité devient visible",
            message: "Collectionnez vos badges quotidiens et progressez dans les défis du mois et de l’année."
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient.fastNight.ignoresSafeArea()
            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button("Passer", action: completion)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 24)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 34) {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 190, height: 190)
                                    .shadow(color: item.colors[0].opacity(0.45), radius: 45)
                                Image(systemName: item.symbol)
                                    .font(.system(size: 76, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .symbolEffect(.pulse, options: reduceMotion ? .nonRepeating : .repeating)
                            }
                            VStack(spacing: 14) {
                                Text(item.title)
                                    .font(.largeTitle.bold())
                                    .multilineTextAlignment(.center)
                                Text(item.message)
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.72))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 28)
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if page == pages.count - 1 {
                        completion()
                    } else {
                        withAnimation(.snappy) { page += 1 }
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Créer mon programme" : "Continuer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                }
                .buttonStyle(.plain)
                .background(.white, in: Capsule())
                .foregroundStyle(Color.fastNavy)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
            }
        }
    }
}

private struct WelcomePage {
    let symbol: String
    let colors: [Color]
    let title: String
    let message: String
}
