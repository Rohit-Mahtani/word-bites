import SwiftUI

struct StatsView: View {
    @ObservedObject var statsStore: StatsStore
    let onBack: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.pageTop, Theme.pageBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    BackButton(action: onBack)
                    Spacer()
                }
                .padding(.bottom, 16)

                Text("Best Scores")
                    .font(Theme.archivoSemiBold(26))
                    .foregroundColor(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 20)

                VStack(spacing: 10) {
                    ForEach(BoardCategory.allCases, id: \.self) { category in
                        categoryRow(category)
                    }
                }

                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
        }
    }

    private func categoryRow(_ category: BoardCategory) -> some View {
        HStack {
            Text(category.displayName)
                .font(Theme.archivoSemiBold(13))
                .foregroundColor(Theme.ink)

            Spacer()

            HStack(spacing: 18) {
                statColumn(value: "\(statsStore.highScore(for: category))", label: "score")
                statColumn(value: "\(statsStore.highWordCount(for: category))", label: "words")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.cardTranslucent)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(Theme.archivoSemiBold(16))
                .foregroundColor(Theme.ink)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.textMutedLight)
        }
    }
}
