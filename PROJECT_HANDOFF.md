# Aligned (Word Bites clone) — Project Handoff

Factual summary of the project state as of 2026-08-04. Written to fully catch up a new AI assistant picking this project up cold — no recommendations or opinions included, only what exists and why.

## Repository

- GitHub: https://github.com/Rohit-Mahtani/word-bites
- Owner account: Rohit-Mahtani
- Visibility: Public
- Local path: `C:\Users\riddh\Documents\WORD BITES`
- The app's in-app name/wordmark is **"Aligned"** (changed from "Word Bites" → "Aligners" → "Aligned" — text only: bundle ID `com.rohitmahtani.wordbites`, repo name, folder names, and Xcode project/target names all still say "WordBites"/"wordbites". This was a deliberate scope decision — see "Naming" below.)

## High-level architecture

Two components in one repo (unchanged from the original spec):

1. **WordBitesKit** — a Swift Package (`WordBitesKit/`) containing all game logic with zero UI dependency: models, dictionary loading, tile generation, scoring, solvability/word-finding. Has a full XCTest suite (63 tests as of the latest commit, all passing). Also contains a small command-line demo target, `WordBitesCLI`.
2. **WordBitesApp** — a SwiftUI iOS app (`WordBitesApp/`) that depends on WordBitesKit as a local Swift package and implements the actual game screens.

No Mac is available in this environment, and there never has been — **no SwiftUI code in this project has ever been compiled locally, only via CI.** The app is built via GitHub Actions macOS runners (`xcodegen generate` + `xcodebuild`, code signing disabled) which produces an unsigned `.ipa` artifact. Distribution to other people is via **AltStore** (see "Distribution" below) rather than TestFlight/App Store.

## Naming and provenance

This is a clone of the mobile game "Word Bites." The user renamed the *in-app* text to "Aligners" and later to "Aligned" (welcome-screen wordmark and subtitle, plus `CFBundleDisplayName`) but explicitly scoped both renames to text-only — bundle ID and repo/package names were deliberately left as "wordbites" so the existing AltStore install/signing keeps working without becoming a new app. If this project is ever taken further than personal/friend sideloading (e.g. TestFlight or a public App Store listing), the naming/branding closeness to the original "Word Bites" game is a real consideration worth re-checking at that point — it hasn't been legally reviewed, just visually differentiated via the redesign described below.

## Original spec (confirmed game rules — unchanged all session)

- Board: 8 tiles wide × 9 tiles long (72 cells).
- Exactly 11 tiles dealt per round: 6 single-letter tiles + 5 double-letter tiles.
- Double tiles: fixed, immovable pair of two specific letters, in a fixed reading order, occupying two adjacent cells. Orientation (horizontal/vertical) is assigned at deal time and cannot be changed by the player during a generated round (the custom-board feature lets the player choose orientation at setup time). **A double tile can never have the same letter on both halves** (added this session — see WordBitesKit changes below).
- Vowel count across all 11 tiles (including letters inside double tiles) must total exactly 5 or 6.
- Words are formed via unbroken horizontal or vertical adjacency (Scrabble-style), not diagonal/free-form.
- Timer: 80 seconds per timed round (`GameViewModel.roundSeconds`). Untimed mode now has a real stop-clock (elapsed time counts up and displays in the HUD) instead of no timer at all.
- Scoring table (exact): 3 letters = 100 pts, 4 = 400, 5 = 800, 6 = 1400, 7 = 1800, 8 = 2200, 9 = 2600. 2-letter words are not scored/not valid.
- Dictionary: **a custom word list the user compiled themselves** (confirmed safe to publish publicly), replacing the original spec's ENABLE1. 163,325 words, one per line, uppercase, deliberately capped at 9 letters (matching the board's longest possible line — the 9-row column) rather than including longer words that could never be formed.

## The two high-score board "anchor word" archetypes (core domain knowledge)

This is the single most important piece of domain knowledge for the "Scoring Potential" slider feature, and it took several rounds of back-and-forth with the user (including real screenshots of the actual Word Bites app, a letter-frequency study, and pro-player "hook order" notes) to pin down correctly. Do not rederive this from first principles — it's confirmed:

- **PLANTERS** (8 letters: P,L,A,N,T,E,R,S) — works read either horizontally or vertically (the board is 8 wide × 9 tall, so an 8-letter line fits either way). Its critical extra letter is **C** — not part of PLANTERS' own spelling, but near-mandatory for the large family of real words pro players chain off this anchor (e.g. CANTERS, CAPLETS, CARPELS — see the full pro "hook order" transcripts referenced in this session if deeper letter-chain tuning is ever revisited). Favored (non-mandatory) extra letters: **G, D, K, O**.
- **MALIGNERS** (9 letters: M,A,L,I,G,N,E,R,S) — the *only* word long enough to require the full 9-row board height, so it **only** works read vertically; a horizontal line can never exceed 8 cells.
- **ALIGNERS** (8 letters: A,L,I,G,N,E,R,S) — the horizontal fallback for the same letter family when the M can't fit in an 8-wide row.
- Both ALIGNERS/MALIGNERS' critical extra letter is **T**.
- These anchor words being "guaranteed present + critical letter present + physically assemblable" is reserved **strictly for `potential == 1` (max slider)** — this was an explicit correction requested by the user after an earlier implementation let the full guaranteed combo appear at *any* nonzero slider position. Below max, generation instead progressively biases toward the anchor family's own letters (excluding the critical letter, and never covering every letter of the family) — see `HighScoreBoardGenerator.swift` below.

## WordBitesKit — file-by-file

Located at `WordBitesKit/Sources/WordBitesKit/`:

- `Models/Position.swift` — grid coordinate + `TileOrientation` enum (horizontal/vertical).
- `Models/Tile.swift` — `SingleTile`, `DoubleTile` (firstLetter/secondLetter/orientation), `Tile` enum wrapping both. Also has `Tile.extensions(forLineDirection:)` (added this session) — the ways a tile can extend a candidate word string along a line running in a given direction: a single tile always offers just its one letter; a double tile offers **both letters together** only when its own fixed orientation matches the line direction (its two cells are already adjacent within that line — there's no way to use one and not the other), or **either letter alone** when perpendicular to the line (only one of its two cells actually sits in that line; the other is in an adjacent, uninvolved row/column). This is the core primitive behind the "direction-aware" solver fix described below.
- `Models/Board.swift` — 8×9 grid. Occupancy is tracked by owning tile ID (not just letter value). Provides `place`, `remove`, `canPlace`, `letter(at:)`, `tileID(at:)`, `word(through:direction:)`.
- `Models/Placement.swift` — `Placement` struct: tileID + origin Position + direction.
- `Models/Deal.swift` — the 11-tile bundle for a round; `singleTileCount`/`doubleTileCount` constants (6/5); `satisfiesHardConstraints` (tile counts + vowel count in {5,6}).
- `Dictionary/Trie.swift` — prefix trie used internally by `WordDictionary`.
- `Dictionary/WordDictionary.swift` — loads a word list (one word per line), filters to 3+ letters, uppercases. `loadDefault()` loads the bundled `wordlist.txt` resource (**renamed from `loadEnable1()`** — the bundled dictionary is no longer ENABLE1). `load(from:)` loads an arbitrary file path (used by the CLI's `WORDBITES_DICTIONARY_PATH` env-var override for local testing, gitignored, never committed).
- `Generation/LetterFrequency.swift` — single-letter sampling weights. **Replaced this session**: previously generic English text-frequency percentages, now an **empirical study of real Word Bites board-generation frequency** (numbers supplied directly by the user), which is deliberately flatter than English prose (no single letter dominates the way E does in text).
- `Generation/BigramPool.swift` — weighted pool of 2-letter sequences built by sliding a window across every dictionary word. **Changed this session**: bigrams with the same letter twice (e.g. "LL", "SS") are now excluded from the pool entirely, since a double tile can never have the same letter on both halves.
- `Generation/WeightedSampling.swift` — generic weighted-random-choice helper (unchanged).
- `Generation/BoardGenerator.swift` — the plain/original generator (uniform random within hard constraints + solvability). Still used at `potential == 0` and by `WordBitesCLI`. Unchanged in behavior this session (benefits from the LetterFrequency/BigramPool fixes above automatically).
- `Generation/HookLetterSource.swift` — a small pluggable protocol (`HookLetterSource`, default impl `FrequencyHookLetterSource`) for supplying "hook" bigrams around an anchor word; exists as an extension point for a future more sophisticated pro-data-driven hook selector (not yet built — the pro "hook order" transcripts the user shared were only used to identify the critical/favored letters, not wired into a full ordered-chain generator).
- `Generation/HighScoreBoardGenerator.swift` — **substantially rewritten this session**. Public API (`generateDeal(potential:candidatePoolSize:maxAttemptsPerCandidate:)`) is unchanged, but internally:
  - `AnchorWord` struct: letters + orientation + `criticalHookLetter` + `favoredHookLetters`. Table of 4 entries (PLANTERS×2 orientations, ALIGNERS, MALIGNERS) — see the anchor-word section above.
  - At `potential == 1` (or ≥0.999, tolerating float slider snapping) **only**: `generateAnchorCandidate` guarantees the full anchor word's letters (as many as fit on single tiles, one single-tile slot always reserved for the critical hook letter — a single tile has no orientation, so it's always alignable — remaining "overflow" anchor letters each ride their own double tile paired with a hook letter, oriented **perpendicular** to the anchor's own line direction so they can contribute just their anchor letter without corrupting the spelling).
  - Below max potential: `generateHookBiasedCandidate` biases single tiles toward a randomly-chosen anchor family's own letters + favored extras — the *number* biased in scales with `strength` — but **always excludes the critical letter and never covers every pool letter**, so the full guaranteed combo genuinely cannot appear below max.
  - Both paths still run through the pre-existing "generate N candidates, keep whichever scores highest via `WordFinder`+`Scorer`" selection, and `candidatePoolSize` itself scales with potential — so every potential level is benchmarked by actual solver-discoverable score, not just by which letters got included (this was a specific design goal the user asked for).
  - A `sampleDifferentLetter(from:favoring:using:)` helper guards every ad-hoc double-tile construction against producing the same letter twice.
- `Scoring/Scorer.swift` — the exact points-by-length table (unchanged).
- `Solvability/SolvabilityChecker.swift` — **rewritten this session, twice**. First pass: made "direction-aware" — `isSolvable` now tries both a horizontal-line and a vertical-line search pass per tile (via `Tile.extensions(forLineDirection:)`), instead of one direction-blind pass that let a double tile always contribute both-or-either letter regardless of physical realizability. Second pass: the per-direction search length cap was wrong — it used one blanket `max(Board.columnCount, Board.rowCount) = 9` for both directions, which wrongly let a *horizontal* search find 9-letter words by stitching single letters from several different vertical doubles scattered across different rows (impossible — a horizontal line is at most 8 cells). Fixed via `SolvabilityChecker.maxWordLength(for direction:)`, direction-specific (8 for horizontal, 9 for vertical).
- `Solvability/WordFinder.swift` — exhaustive version of the same search (returns every valid word, not just first-match); received the identical direction-aware + per-direction-length-cap fixes as `SolvabilityChecker`, since both share the same underlying correctness requirement. This directly targeted a real, repeatedly-reported bug: words the player scored live during a round were sometimes missing from the post-round solver's "all possible words" list, and separately, the solver was later found to claim impossible 9+ letter horizontal words existed. Both were genuine algorithmic bugs, now fixed and covered by regression tests.

Resource: `Resources/wordlist.txt` — the bundled custom dictionary (163,325 words after the earlier ENABLE1→custom swap; the previous handoff's word-count/provenance notes about ENABLE1 no longer apply).

Tests (`WordBitesKit/Tests/WordBitesKitTests/`): `ModelsTests.swift`, `ScorerTests.swift`, `WordDictionaryTests.swift`, `GenerationTests.swift` (now also covers same-letter-bigram exclusion), `BoardGeneratorTests.swift`, `HighScoreBoardGeneratorTests.swift` (rewritten for the anchor-word design — covers the critical-letter guarantee, the perpendicular-orientation rule, the sub-max-never-produces-full-signature guarantee, the hook-bias-scales-with-strength property, and no-duplicate-double-letters), `SolvabilityCheckerTests.swift`, `WordFinderTests.swift` (covers both the partial-double-usage fix and the per-direction-length-cap fix), plus a **new** `LiveScoringSolverConsistencyTests.swift` — an empirical regression test that generates many random boards (mixing `BoardGenerator` and `HighScoreBoardGenerator` at varying potential), scatters tiles allowing adjacency (deliberately not the strict no-touch scatter, which would make the test vacuous), reads every live-readable word off the board the same way `GameViewModel.scanForNewWords` does, and asserts every one of them is discoverable by `WordFinder` — this is the test that actually proves the live-play-vs-solver mismatch bug is closed, not just theoretically fixed. All ~63 tests pass as of the latest commit.

`WordBitesCLI` (`WordBitesKit/Sources/WordBitesCLI/main.swift`) — unchanged in behavior; still respects `WORDBITES_DICTIONARY_PATH` for local testing, otherwise loads the bundled default dictionary via `loadDefault()`.

## WordBitesApp — file-by-file

Located at `WordBitesApp/Sources/WordBitesApp/`:

- `WordBitesApp.swift` — `@main` App entry point. Root view is `RootView`, now `.preferredColorScheme(.light)` (**changed this session** — was `.dark`, a leftover from the old dark-blue theme that would have mismatched the new light redesign). `.buttonStyle(HapticButtonStyle())` applied here so every `Button` anywhere in the app gets a haptic automatically. `.onAppear { MusicPlayer.start() }` starts the looping background track.
- `RootView.swift` — owns the long-lived `AppCoordinator`, `StatsStore`, `GameViewModel`, `CustomBoardStore`. In-game back button now routes to `.modeSelect` instead of `.welcome` (changed this session).
- `AppCoordinator.swift` — `AppScreen` enum (unchanged cases). **Gained** `lastMode: GameMode` and `lastScoringPotential: Double` published properties this session, so Mode Select's settings persist across "New Game" instead of resetting to defaults every time (previously local `@State` on `ModeSelectView`). The Random/Custom board toggle already persisted correctly before (lives in `CustomBoardStore`, which was already app-root-scoped).
- `WelcomeView.swift` — title screen: tile-styled "ALIGNED" wordmark (each tile at a slight fixed alternating rotation — see `TileLogoView.swift`), italic "Welcome to Aligned" subtitle, "Single Player"/"High Scores" buttons. Restyled this session to the parchment theme.
- `ModeSelectView.swift` — Timed/Untimed and Random/Custom pickers (now a custom `SegmentedPill` component, not SwiftUI's native `.pickerStyle(.segmented)`, to match the redesign's solid-gold-active-segment look — this is why it needs an explicit `FeedbackPlayer.buttonTapped()` call, since it's not a real `Button`). Scoring Potential slider. `mode`/`scoringPotential` are now `@Binding` (from `AppCoordinator`, see above) instead of local `@State`. Also defines the shared `BackButton` component (restyled this session) used across most screens, and the new `SegmentedPill` component.
- `CustomBoardStore.swift` — holds the player's manually-entered board. **Gained** `CustomBoardFocusField` enum and `nextEmptyField(after:)` this session, powering auto-advance-to-next-empty-tile on the custom board screen.
- `CustomBoardView.swift` — editor screen, restyled to the dashed-placeholder look this session; double-tile pairs now render as one fused shape (matching the in-game tile treatment) instead of two separately-bordered halves. Wires up `@FocusState` + the auto-advance behavior.
- `LetterInputTile.swift` — single-character tile-styled `TextField`. **Gained** `field`/`focusedField` (for auto-advance), `isValid` (rejects typing the same letter into both halves of a double tile), `onFilled` callback, and `cornerRadius`/`showBorder` params (so it can render border-less/square when used as one half of a fused double-tile pair).
- `GameViewModel.swift` — `@MainActor` `ObservableObject` driving one round. Key changes this session:
  - `startRound(mode:scoringPotential:)` no longer hangs silently if `HighScoreBoardGenerator.generateDeal` throws — falls back to a plain `BoardGenerator`, and if that also fails, sets `isDealing = false` + a `loadError` message (previously: infinite "Dealing..." spinner, no error surfaced).
  - Untimed mode now has a real `elapsedSeconds` published property, ticking every second like the timed countdown, displayed in the HUD.
  - `attemptMove` no longer reverts a tile all the way back to its drag-start position when dropped on an occupied cell — `nearestFreePlacement(for:near:direction:)` does an expanding-ring search for the nearest actually-open cell instead.
  - `draggingTileID` gate (used by `BoardView`, see below) prevents two different tiles being dragged simultaneously by two fingers.
  - The no-two-tiles-touching `scatterTiles` static algorithm is unchanged.
  - `boardSource: BoardSource` tracked per round (random vs. custom), passed to `StatsStore.record(score:wordCount:category:)` so each of the 4 mode×source combinations gets its own independently-tracked high score/word count (see `StatsStore.swift`).
- `GameView.swift` — **restructured this session** for the redesign: the HUD is now a floating overlay pinned to the top of the screen (a `VStack` with `.frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.top)`), and the board sits in a *separate* container that's vertically centered in the full screen height (`VStack{Spacer();board;Spacer()}.frame(maxHeight:.infinity)`) — so the board's position never shifts when the HUD's own height changes (this fixes a real historical "HUD pushes the board down" class of bug, called out explicitly in the design handoff). `cellSize` is cached in `@State`, updated only via a background `GeometryReader`'s `onAppear`/`onChange(of: geometry.size.width)` — **not** recomputed inline on every body evaluation, which used to happen on every per-second timer tick and every drag update and was the actual root cause of an earlier "board jitters" bug report (fixed this session, along with two *other* distinct causes of jitter/drag bugs — see below).
- `HUDView.swift` — **rebuilt this session**: back button (circle, top-left) + small circular "?" button (top-right, same action as the old text "Solver" button — ends the round early, jumps to Solver) on one row; a cream score card below showing "WORDS: n" / "SCORE: 0000"-style (zero-padded to 4 digits); a floating dark time pill (mm:ss format for *both* timed-countdown and untimed-elapsed, red text under 15s remaining in timed mode).
- `BoardView.swift` — renders the 8×9 grid. **Two real bugs fixed this session, independent of the visual redesign**:
  1. The drag-end handler used to wrap the `viewModel.attemptMove(...)` call itself in `withAnimation(...)`, which put *every* tile, the HUD, and the board's own layout into one shared animated transaction rather than just the tile that moved — this could both block a second tile's drag gesture from being recognized until that transaction settled, and let unrelated layout (the board's position) get swept into the same animation. Fixed by scoping the animation to just the moved tile's own `.position()` via `.animation(_:value:)` instead.
  2. True simultaneous two-finger dragging of two different tiles was possible (each tile has its own independent `DragGesture`, with nothing preventing two from being active at once). Fixed with a `draggingTileID`-based gate: `onChanged`/`onEnded` now check `draggingTileID == nil || draggingTileID == tile.id` before responding, so only the tile that already claimed the active drag responds until it's released.
  Visually, `BoardView` also now renders a flat `Theme.boardPanel` fill with a dashed dotted grid (via `Theme.dotTextureBase`) instead of a checkerboard, per the redesign.
- `TileView.swift` — renders one tile. **Redesigned this session**: single unified `TileBackground()` gradient/grain fill (not two flat colors for single vs. double), and double tiles now render as **one fused shape** — a single border/background/shadow spans both letters with no divider/seam between them (previously each half had its own background with a visible 1px divider `Rectangle` between them).
- `TileBackground.swift` — **new this session**: the shared diagonal warm-wood gradient + fine grain-line texture used by every tile (`TileView`, `TileLogoView`, `LetterInputTile`) so they all read as the same material.
- `DotTexture.swift` — **new this session**: a `Canvas`-based repeating dot pattern (replaces `CheckerboardView.swift`, which is now fully unused and was **deleted**) — used for the game screen's background texture.
- `TileLogoView.swift` — renders text as tile-styled letter badges (the "ALIGNERS" wordmark). **Changed this session**: each tile now sits at a slight independent rotation, following a fixed alternating pattern (`Self.rotations`, not randomized per render) for a hand-placed feel; uses the new `TileBackground()`/Archivo font/tile border+shadow treatment matching real game tiles.
- `CheckerboardView.swift` — **deleted this session** (both `CheckerboardView` and `FullScreenCheckerboard` became fully unused once the board switched to a flat panel + dotted grid and the game background switched to a gradient + dot texture).
- `ScoreToastView.swift` — shows the most recently scored word + point value. **Two behavioral fixes this session**: (1) the chip is now permanently mounted — it never inserts/removes from the view hierarchy via `if let toast {...}.transition(...).id(toast.id)` like before; only its opacity/scale animate between shown/hidden. That conditional mount/unmount (and the `.animation(value:)` driving it) was very likely the actual root cause of a "board jitters specifically when words are scored" bug report — insertion/removal of a real view can ripple into the surrounding VStack's layout during the transition, whereas opacity/scale changes on an always-present view never affect layout. (2) A separate `popScale` state now pulses a quick scale-bounce on **every** new word (via explicit `withAnimation`/`withTransaction` in `onChange(of: toast)`, keyed to any change — not just nil→visible), so rapid back-to-back words each still get their own snappy "pop" with zero added delay or queueing — the text swap itself remains instant.
- `FlowLayout.swift` — custom wrapping-row `Layout` (unchanged), used for the custom board's single-tile row and the solver screen's word chips.
- `SolverView.swift` — post-round screen. **Header layout bug fixed this session**: the old wide "New Game" text button (right side) made the back-button/title/right-button row asymmetric, throwing off true centering of the "Solver" title. Replaced with a same-size (36pt) circular gold "+" button (identical action: `onNewGame`) so both sides of the header are equal width and the title centers correctly. Word-length groups are now cards (translucent white fill) instead of plain sections; word chips restyled, still visually distinguishing found-vs-not-found words.
- `StatsStore.swift` — **rewritten this session** from a single global high-score pair to 4 independently-tracked buckets. `BoardSource` enum (`.random`/`.custom`) + `BoardCategory` enum (`.timedRandom`/`.timedCustom`/`.untimedRandom`/`.untimedCustom`, with `init(mode:source:)` and a `displayName`), each persisted via its own pair of `UserDefaults` keys. `record(score:wordCount:category:)` / `highScore(for:)` / `highWordCount(for:)`.
- `StatsView.swift` — **rewritten this session** from a 2×2 `LazyVGrid` to a vertical list of 4 row-cards (mode-combo label left, score+words right-aligned in two stat columns), content top-anchored rather than vertically centered — per the design handoff, which explicitly called out both of these as intentional changes from an earlier design iteration.
- `FeedbackPlayer.swift` — haptic feedback. **Gained** `buttonTapped()` (light impact) and the `HapticButtonStyle: ButtonStyle` wrapper this session, applied once at the app root so every real `Button` gets a haptic without touching individual call sites; non-`Button` tap targets (currently just `ModeSelectView`'s `SegmentedPill`, which uses `onTapGesture`) call `FeedbackPlayer.buttonTapped()` explicitly. Still haptics-only — no sound effects (see `MusicPlayer.swift` below for the one piece of audio that does exist).
- `MusicPlayer.swift` — **new this session**: loops a background music track (`Resources/BackgroundMusic.mp3`, user-provided) continuously from app launch via `AVAudioPlayer`, `.ambient` audio session category (respects the device's silent switch, yields to other audio).
- `Theme.swift` — **fully rewritten this session** for the visual redesign. Previously a dark-blue/light-peach palette with light text on dark backgrounds; now a light warm "parchment" palette with dark ink text on light backgrounds throughout (every old token's *role* inverted, not just its value — see below). Also gained three font helpers (`archivoMedium(_:)`, `archivoSemiBold(_:)`, `archivoBold(_:)`) wrapping the bundled Archivo font's verified PostScript names.

## Visual redesign (design handoff "4a")

The user commissioned a visual redesign via Claude Design and provided a high-fidelity handoff package (colors, typography, spacing, per-screen layout, all pixel-specified). Implemented in full this session. Key facts worth knowing if extending this further:

- **Palette**: light parchment gradient page backgrounds (`#F6EFDD`→`#E9DCBC`), a deeper-tan gradient + dotted texture for the game screen, wood-grain gradient tiles (`#F5DFB8`/`#E9C68E`/`#F3D8AC`/`#E2BA80`, 135° diagonal), dark ink text (`#3B2A1E` primary), gold accent (`#D9B23F`→`#B08E2E`). Full token list is in `Theme.swift`.
- **Typography**: Archivo (Google Font) replaces Georgia everywhere except small uppercase labels (SCORE/WORDS/TIME captions, section labels), which stay on SwiftUI's `.system` font per the spec.
- **Font bundling detail worth preserving**: Archivo has **no static per-weight files** on Google Fonts — only one variable font (`Archivo[wdth,wght].ttf`, bundled at `WordBitesApp/Sources/WordBitesApp/Resources/Archivo.ttf`, registered via `UIAppFonts` in `project.yml`). Its named instances were verified by downloading the font and binary-parsing its `name`/`fvar` tables directly (no Mac/fonttools available, so a small standalone Python script was written to parse the TTF tables by hand) — the usable PostScript names are prefixed **`ArchivoRoman-`**, not `Archivo-` (e.g. `ArchivoRoman-Medium`, `ArchivoRoman-SemiBold`, `ArchivoRoman-Bold`). If font rendering ever looks wrong (falls back to system font silently), this naming is the first thing to re-verify.
- Two explicit historical layout bugs called out in the handoff itself (and fixed as part of implementing it): the HUD used to push the board down instead of floating over it, and the Solver screen's asymmetric header (wide "New Game" button vs. small back button) prevented the title from truly centering.
- The redesign was visual/layout only — no `WordBitesKit` or game-logic changes.
- **Unconfirmed as of this writing**: the user was asked to sanity-check on-device that Archivo actually renders (vs. silently falling back to system font) and that the new floating-HUD layout doesn't reintroduce board jitter. No explicit confirmation received yet in this session.

## Distribution

The app has no paid Apple Developer Program enrollment. Distribution to other people (beyond the user's own device) is set up via **AltStore sideloading**, chosen over TestFlight/App Store/ad-hoc (all of which require the $99/year Developer Program — these were discussed as options but not pursued):

- A **GitHub Release** (tag `sideload-v1.0`) hosts the built `.ipa` as a permanent, unauthenticated download URL — necessary because GitHub Actions CI artifacts are ephemeral/authenticated and can't be used as an AltStore `downloadURL`.
- `altstore-source.json` at the repo root is the AltStore "source" file, publicly fetchable at `https://raw.githubusercontent.com/Rohit-Mahtani/word-bites/master/altstore-source.json`. Schema was verified against AltStore's own official source (`https://cdn.altstore.io/file/altstore/apps.json`) before writing it, to make sure it actually parses — uses both the legacy top-level `version`/`downloadURL`/`size` fields and the modern `versions[]` array for maximum compatibility.
- **To ship an update to everyone who's added the source**: build the new `.ipa`, create a new GitHub Release asset (or update the existing one), then bump `altstore-source.json`'s `version`/`versionDate`/`versionDescription`/`downloadURL`/`size`/`sha256` and prepend a new entry to `versions[]`, commit, push. Existing AltStore installs will then show an available update automatically, same as any other app.
- Each person still needs to install AltStore + AltServer themselves (their own free Apple ID, one-time setup) and keep AltServer reachable periodically (same 7-day free-Apple-ID re-signing limitation as the user's own install — this is an Apple platform limitation, not something AltStore or this setup can remove).
- Other options discussed but not implemented: **ad-hoc distribution** ($99/yr Developer Program, up to 100 registered device UDIDs, no AltServer needed by testers, ~1yr cert validity) and **TestFlight** ($99/yr, up to 10,000 external testers via a public link, no UDID registration, the standard recommended path if this ever needs to scale past friends) and a **full public App Store listing** (same $99/yr enrollment as TestFlight, permanent/public, needs App Store review + assets — the naming/branding consideration under "Naming" above would need to be resolved first).

## Build/CI

- `.github/workflows/wordbiteskit-tests.yml` — triggers on changes under `WordBitesKit/**`; runs `swift build`, `swift test`, and a CLI demo step on `macos-latest`.
- `.github/workflows/wordbitesapp-build.yml` — triggers on changes under `WordBitesApp/**` or `WordBitesKit/**`; runs `xcodegen generate`, `xcodebuild` (Release, `-sdk iphoneos`, `CODE_SIGNING_ALLOWED=NO`), packages the resulting `.app` into an unsigned `.ipa`, uploads it as a workflow artifact named `WordBitesApp`.
- `WordBitesApp/project.yml` — xcodegen project definition. **Gained** a `UIAppFonts: ["Archivo.ttf"]` entry this session (font registration). Otherwise unchanged: iOS 16 deployment target, local `WordBitesKit` package dependency, bundle ID `com.rohitmahtani.wordbites`, iPhone-only.

## Local development environment notes

- No Mac available, ever. Windows machine has: the official Swift toolchain for Windows (rarely used directly this session — most `swift build`/`swift test` runs went through WSL instead, see below), and a WSL2 Ubuntu instance with a separately-built Swift toolchain, used for **all** `swift build`/`swift test` runs this session via:
  ```
  export PATH=$HOME/swift-6.3.3-RELEASE-ubuntu24.04/usr/bin:$PATH
  export LD_LIBRARY_PATH=$HOME/swift-compat-libs:$LD_LIBRARY_PATH
  cd "/mnt/c/Users/riddh/Documents/WORD BITES/WordBitesKit" && swift test
  ```
  (`swift-compat-libs` contains a `libxml2.so.2` shim needed for `swift-build` to run on this WSL Ubuntu install.)
- **WordBitesApp (SwiftUI) has never been compiled locally at all** — every single UI change this session was verified only by pushing and waiting for `xcodebuild` on GitHub Actions to succeed. This has generally gone well (only occasional needed fixes caught by CI), but it's worth knowing that any SwiftUI change carries real, unverified-until-CI compile risk.
- AltServer and AltStore are installed (Windows + the user's iPhone) for sideloading, using the user's free Apple ID (no paid Developer Program).

## Known open items (as of this writing, not yet independently reproduced/confirmed beyond what's noted)

- Archivo font rendering and the new floating-HUD/centered-board layout were both shipped this session but not yet explicitly confirmed by the user as looking correct on-device.
- The pro-player "hook order" data the user provided (specific word chains like "plaster→cantles→antlers→panters→planters→...") was only used to extract the critical/favored letter sets for each anchor archetype — it was **not** wired into a full ordered-chain-aware hook generator. `HookLetterSource` exists as a pluggable extension point for this if it's ever revisited.
- If distribution ever needs to go beyond AltStore (TestFlight/App Store), the naming/branding closeness to the original "Word Bites" game (see "Naming" section) hasn't been legally reviewed.

## Version control state

Latest commits on `master` (most recent first, as of this handoff):
- `f623462` — Add AltStore source for sideload distribution
- `607d3bd` — Add app-wide button haptics and a per-word toast pop animation
- `21eb6b2` — Visual redesign: parchment/wood theme (design handoff 4a)
- `6d8f70e` — Add nav/settings polish, tile texture, and gate scoring potential
- `afaad93` — Stop board jitter on word scoring by never unmounting the toast
- `1ef2ace` — Block simultaneous multi-touch drags, cache board cell size
- `811d13d` — Stop blocking sequential tile drags and board jitter
- `f59fff7` — Fix solver claiming words too long for a horizontal row
- `7411a25` — Make WordFinder direction-aware and guarantee anchor hook letters
- `b84b7ff` — Rename in-app wordmark and welcome text to ALIGNERS
- `bd59e2b` — Add anchor-word high-score boards, fix solver gap, and three gameplay tweaks
- `567135b` — Replace ENABLE1 with a custom bundled word list
- (earlier history unchanged from the original handoff — custom board option, tile-overlap fix, initial app/kit scaffolding)

All changes described in this document have been committed and pushed to `master`, and the most recent CI runs for both the WordBitesKit test workflow and the WordBitesApp build workflow succeeded. There is also a separate `sideload-v1.0` release tag (not a branch) hosting the current distributable `.ipa`.
