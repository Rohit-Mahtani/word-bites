import SwiftUI

struct HUDView: View {
    let score: Int
    let timeRemaining: Int
    let onNewBoard: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            logo
            HStack {
                hudItem(label: "Score", value: "\(score)", lowTime: false)
                Spacer()
                Button(action: onNewBoard) {
                    Text("New Board")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.woodDeep)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(colors: [Theme.accent, Theme.accentDeep], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                Spacer()
                hudItem(label: "Time", value: "\(max(0, timeRemaining))", lowTime: timeRemaining <= 15)
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
        .background(
            LinearGradient(colors: [Theme.woodLight, Theme.wood, Theme.woodDeep], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private static let logoCharacters = Array("WORD BITES")

    private var logo: some View {
        HStack(spacing: 4) {
            ForEach(Self.logoCharacters.indices, id: \.self) { index in
                let ch = Self.logoCharacters[index]
                if ch == " " {
                    Color.clear.frame(width: 10)
                } else {
                    Text(String(ch))
                        .font(.custom("Georgia-Bold", size: 17))
                        .foregroundColor(Theme.ink)
                        .frame(width: 28, height: 28)
                        .background(Theme.tile)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private func hudItem(label: String, value: String, lowTime: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.2)
                .foregroundColor(Theme.creamDim)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(lowTime ? Color(hex: 0xB5533C) : Theme.cream)
        }
        .frame(minWidth: 56)
    }
}
