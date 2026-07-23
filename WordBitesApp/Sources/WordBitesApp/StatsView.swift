import SwiftUI

struct StatsView: View {
    @ObservedObject var statsStore: StatsStore
    let onBack: () -> Void

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

                VStack(spacing: 28) {
                    Text("Best Scores")
                        .font(.custom("Georgia-Bold", size: 22))
                        .foregroundColor(Theme.pageText)

                    HStack(spacing: 18) {
                        statCard(label: "High Score", value: "\(statsStore.highScore)")
                        statCard(label: "Most Words", value: "\(statsStore.highWordCount)")
                    }
                }

                Spacer()
                Spacer()
            }
            .padding(20)
        }
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Theme.chromeText)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundColor(Theme.chromeTextDim)
        }
        .frame(width: 140, height: 100)
        .background(
            LinearGradient(colors: [Theme.chrome, Theme.chromeMid], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
