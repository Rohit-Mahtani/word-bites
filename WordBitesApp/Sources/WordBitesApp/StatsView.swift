import SwiftUI

struct StatsView: View {
    @ObservedObject var statsStore: StatsStore
    let onBack: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Theme.pageGlow, Theme.pageDeep],
                center: .init(x: 0.5, y: 0.2),
                startRadius: 10,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    BackButton(action: onBack)
                    Spacer()
                }
                Spacer()

                VStack(spacing: 24) {
                    Text("Best Scores")
                        .font(.custom("Georgia-Bold", size: 22))
                        .foregroundColor(Theme.pageText)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(BoardCategory.allCases, id: \.self) { category in
                            categoryCard(category)
                        }
                    }
                    .frame(maxWidth: 340)
                }

                Spacer()
                Spacer()
            }
            .padding(20)
        }
    }

    private func categoryCard(_ category: BoardCategory) -> some View {
        VStack(spacing: 10) {
            Text(category.displayName.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(Theme.chromeTextDim)
                .multilineTextAlignment(.center)

            VStack(spacing: 2) {
                Text("\(statsStore.highScore(for: category))")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Theme.chromeText)
                Text("High Score")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.chromeTextDim)
            }

            VStack(spacing: 2) {
                Text("\(statsStore.highWordCount(for: category))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Theme.chromeText)
                Text("Most Words")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.chromeTextDim)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            LinearGradient(colors: [Theme.chrome, Theme.chromeMid], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
