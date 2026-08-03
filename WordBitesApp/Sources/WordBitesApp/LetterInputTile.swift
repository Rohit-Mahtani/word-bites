import SwiftUI

/// A tile-styled single-character input. Typing anything keeps only the
/// most recently typed letter, so pasting or autocorrect can't leave more
/// than one character behind.
struct LetterInputTile: View {
    @Binding var letter: Character?
    var size: CGFloat = 46
    let field: CustomBoardFocusField
    var focusedField: FocusState<CustomBoardFocusField?>.Binding
    /// Rejects a typed letter if it wouldn't be valid here (e.g. it would
    /// duplicate the other half of the same double tile) -- true by default.
    var isValid: (Character) -> Bool = { _ in true }
    /// Fired once, right when this field goes from empty to filled with a
    /// valid letter -- the caller advances focus to the next empty field.
    var onFilled: () -> Void = {}

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
            .background(
                Group {
                    if letter == nil {
                        Theme.tile.opacity(0.55)
                    } else {
                        TileBackground()
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(letter == nil ? Theme.error.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
            .focused(focusedField, equals: field)
            .onChange(of: text) { newValue in
                let filtered = newValue.uppercased().filter(\.isLetter)
                var last = filtered.last.map(String.init) ?? ""
                if let ch = last.first, !isValid(ch) {
                    last = ""
                }
                text = last
                let wasEmpty = letter == nil
                letter = last.first
                if wasEmpty, letter != nil {
                    onFilled()
                }
            }
            .onAppear {
                if let letter { text = String(letter) }
            }
    }
}
