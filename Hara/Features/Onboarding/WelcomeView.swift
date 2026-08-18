import SwiftUI

struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let completion: () -> Void
    @State private var page = 0

    private let pages = [
        WelcomePage(
            symbol: "bolt.heart.fill",
            colors: [.haraCoral, .haraOrange],
            title: "Vos abdos, chaque jour",
            message: "Une séance courte, complète et différente, pensée pour tenir dans votre quotidien."
        ),
        WelcomePage(
            symbol: "figure.core.training",
            colors: [.haraBlue, .purple],
            title: "Chaque mouvement, démontré",
            message: "La position de départ, la respiration et l’erreur à éviter, pendant que le mouvement se joue sous vos yeux."
        ),
        WelcomePage(
            symbol: "medal.star.fill",
            colors: [.haraOrange, .yellow],
            title: "La régularité devient visible",
            message: "Séries, rangs et hauts faits : ce que vous faites chaque jour finit par se voir."
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient.haraNight.ignoresSafeArea()
            VStack(spacing: 22) {
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button("Passer") {
                            Haptics.tap()
                            completion()
                        }
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
                // Swiping between pages is a selection like any other, and it
                // was the one gesture in the app that answered with nothing.
                .onChange(of: page) { _, _ in Haptics.selection() }

                Button {
                    if page == pages.count - 1 {
                        Haptics.begin()
                        completion()
                    } else {
                        Haptics.tap()
                        withAnimation(Motion.honouring(reduceMotion, Motion.content)) { page += 1 }
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Créer mon programme" : "Continuer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                }
                .buttonStyle(.card)
                .background(.white, in: Capsule())
                .foregroundStyle(Color.haraNavy)
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
