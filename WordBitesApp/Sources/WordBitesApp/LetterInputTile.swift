import SwiftUI

/// A tile-styled single-character input. Typing anything keeps only the
/// most recently typed letter, so pasting or autocorrect can't leave more
/// than one character behind.
struct LetterInputTile: View {
    @Binding var letter: Character?
    var size: CGFloat = 46

    @State private var text: String = ""

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
            .multilineTextAlignment(.center)
            .font(.custom("Georgia-Bold", size: size * 0.45))
            .foregroundColor(Theme.ink)
            .frame(width: size, height: size)
            .background(letter == nil ? Theme.tile.opacity(0.55) : Theme.tile)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(letter == nil ? Theme.error.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
            .onChange(of: text) { newValue in
                let filtered = newValue.uppercased().filter(\.isLetter)
                let last = filtered.last.map(String.init) ?? ""
                text = last
                letter = last.first
            }
            .onAppear {
                if let letter { text = String(letter) }
            }
    }
}
