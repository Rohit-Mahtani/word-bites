# Aligned (Word Bites clone) — Project Handoff

Factual summary of the project state as of 2026-08-10. Written to fully catch up a new AI assistant picking this project up cold — no recommendations or opinions included, only what exists and why.

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
- Double tiles: fixed, immovable pair of two specific letters, in a fixed reading order, occupying two adjacent cells. Orientation (horizontal/vertical) is assigned at deal time and cannot be changed by the player during a generated round (the custom-board feature lets the player choose orientation at setup time). A double tile can never have the same letter on both halves.
- Vowel count across all 11 tiles (including letters inside double tiles) must total exactly 5 or 6.
- Words are formed via unbroken horizontal or vertical adjacency (Scrabble-style), not diagonal/free-form.
- Timer: 80 seconds per timed round (`GameViewModel.roundSeconds`). Untimed mode has a real stop-clock (elapsed time counts up and displays in the HUD).
- Scoring table (exact): 3 letters = 100 pts, 4 = 400, 5 = 800, 6 = 1400, 7 = 1800, 8 = 2200, 9 = 2600. 2-letter words are not scored/not valid.
- Dictionary: a custom word list the user compiled themselves (confirmed safe to publish publicly), replacing the original spec's ENABLE1. 163,325 words, one per line, uppercase, deliberately capped at 9 letters.

## The two high-score board "anchor word" archetypes (core domain knowledge)

This is the single most important piece of domain knowledge for the "Scoring Potential" slider feature. Do not rederive this from first principles — it's confirmed:

- **PLANTERS** (8 letters: P,L,A,N,T,E,R,S) — works read either horizontally or vertically (the board is 8 wide × 9 tall, so an 8-letter line fits either way). Its critical extra letter is **C**. Favored (non-mandatory) extra letters: **G, D, K, O**.
- **MALIGNERS** (9 letters: M,A,L,I,G,N,E,R,S) — the *only* word long enough to require the full 9-row board height, so it **only** works read vertically.
- **ALIGNERS** (8 letters: A,L,I,G,N,E,R,S) — the horizontal fallback for the same letter family when the M can't fit in an 8-wide row.
- Both ALIGNERS/MALIGNERS' critical extra letter is **T**.
- The full anchor-word+critical-letter guaranteed combo is reserved **strictly for `potential == 1` (max slider)**. Below max, generation progressively biases toward the anchor family's own letters (excluding the critical letter, never covering every letter of the family) — see `HighScoreBoardGenerator.swift`.

## WordBitesKit — file-by-file

Located at `WordBitesKit/Sources/WordBitesKit/`. **Unchanged since the previous handoff** — all work this session was in `WordBitesApp` only (sound effects, naming, CI/build config). Summary retained for completeness:

- `Models/Position.swift`, `Models/Tile.swift` (incl. `Tile.extensions(forLineDirection:)`), `Models/Board.swift`, `Models/Placement.swift`, `Models/Deal.swift`.
- `Dictionary/Trie.swift`, `Dictionary/WordDictionary.swift` (`loadDefault()` loads the bundled custom `wordlist.txt`).
- `Generation/LetterFrequency.swift` (empirical Word Bites board-frequency study), `Generation/BigramPool.swift` (excludes same-letter bigrams), `Generation/WeightedSampling.swift`, `Generation/BoardGenerator.swift`, `Generation/HookLetterSource.swift`, `Generation/HighScoreBoardGenerator.swift` (anchor-word design, full guarantee only at `potential == 1`).
- `Scoring/Scorer.swift`.
- `Solvability/SolvabilityChecker.swift` / `Solvability/WordFinder.swift` — direction-aware, per-direction length caps (8 horizontal / 9 vertical).
- Resource: `Resources/wordlist.txt` (163,325 words).
- Tests (`WordBitesKit/Tests/WordBitesKitTests/`): `ModelsTests.swift`, `ScorerTests.swift`, `WordDictionaryTests.swift`, `GenerationTests.swift`, `BoardGeneratorTests.swift`, `HighScoreBoardGeneratorTests.swift`, `SolvabilityCheckerTests.swift`, `WordFinderTests.swift`, `LiveScoringSolverConsistencyTests.swift`. All ~63 tests pass.
- `WordBitesCLI` (`WordBitesKit/Sources/WordBitesCLI/main.swift`) — unchanged.

## WordBitesApp — file-by-file

Located at `WordBitesApp/Sources/WordBitesApp/`. Files with no changes since the last handoff are summarized briefly; files touched this session have full detail.

- `WordBitesApp.swift` — `@main` entry point. `.preferredColorScheme(.light)`, `.buttonStyle(HapticButtonStyle())`, `.onAppear { MusicPlayer.start() }`. Unchanged this session.
- `RootView.swift`, `AppCoordinator.swift` — unchanged this session.
- `WelcomeView.swift` — **renamed this session**: wordmark text is now `"ALIGNED"` (was `"ALIGNERS"`), subtitle now `"Welcome to Aligned"`.
- `TileLogoView.swift` — doc comment updated to not name a specific word (it renders whatever text is passed in); rendering logic (fixed alternating rotation array, indexed via modulo so any word length is safe) unchanged.
- `ModeSelectView.swift`, `CustomBoardStore.swift`, `CustomBoardView.swift`, `LetterInputTile.swift` — unchanged this session.
- `GameViewModel.swift` — unchanged in behavior this session. (A temporary `lastSoundDiagnostic` published property and diagnostic-string return values were added and then fully removed again while debugging inaudible sound effects — see "Sound effects" below. Current state matches the previous handoff's description.)
- `GameView.swift` — unchanged in behavior this session (same temporary-diagnostic-added-then-removed history as above).
- `HUDView.swift`, `BoardView.swift`, `TileView.swift`, `TileBackground.swift`, `DotTexture.swift`, `ScoreToastView.swift`, `FlowLayout.swift`, `SolverView.swift`, `StatsStore.swift`, `StatsView.swift` — unchanged this session.
- `FeedbackPlayer.swift` — **behavior changed this session**. `wordScored(length:)` now also plays a sound (see below), and `tilePickedUp()`/`tilePlaced()` now *attempt* to play `"TilePickup"`/`"TileDrop"` sound resources in addition to their existing haptics — but see "Sound effects" below for why these two specific calls currently no-op (the resource files don't exist in the bundle yet). `buttonTapped()` and `HapticButtonStyle` unchanged.
- `SoundEffectPlayer.swift` — **new this session, currently uncommitted** (see "Version control state"). Replaces the earlier `WordSoundPlayer.swift` (deleted). A generalized one-shot sound player: `SoundEffectPlayer.shared.play(resource:extension:)` looks up a bundled resource by name, and if found, plays it via a freshly-created `AVAudioPlayer` retained in an array until playback finishes (so overlapping/rapid-succession sounds layer instead of cutting off) — same pooling technique as the original `WordSoundPlayer`. If the named resource isn't in the bundle, it silently does nothing (this is why tile pickup/drop currently produce no sound: the code path is wired up but `TilePickup.wav`/`TileDrop.wav` don't exist in `Resources/` yet).
- `MusicPlayer.swift` — unchanged this session.
- `Theme.swift` — unchanged this session.

## Sound effects (the major open thread from this session)

This is unfinished. Read this whole section before touching audio again.

### Original requirement (verbatim, still governing)

> 4 sounds will be needed, one for 3 letter words, one for 4, one for 5, and one for words with 6 or more letters. Lower pitched sounds should be used for the shorter letters and higher for the longer letters. The higher pitched sounds sounds for longer words should be SLIGHTLY longer lasting each increase in pitch. When multiple words are made in quick succession, the correct audio should be played on top of whatever previous audio was playing, there should be no glitches.

Tile pickup/drop sounds were a later addition to scope, requested mid-session once the user recalled an older, since-removed synthesized sound system (see below).

### What's actually shipped right now

- `WordSound3.wav` / `WordSound4.wav` / `WordSound5.wav` / `WordSound6.wav` in `WordBitesApp/Sources/WordBitesApp/Resources/` — **committed, bundled, and confirmed working on-device.** These are a wind-chime source (Pixabay, "WindChime1" by perrydolia/freesound_community, Pixabay Content License, no attribution required) pitch-shifted into a C5/E5/G5/C6 ascending arpeggio, one tier per word length, with ascending duration per tier, peak-normalized to −1 dBFS (see "The loudness bug" below for why peak normalization matters here specifically).
- The user confirmed these are audible, but does **not** like the tone/timbre itself ("i dont think chimes like this work") and wants something that sounds more like the actual Word Bites game's sound (see "Reference-audio analysis" below). No replacement has been approved yet.
- Tile pickup/drop: **no sound currently plays** — haptics only, same as it's been since the original synthesized system was removed months ago (commit `776f753`, "Remove synthesized sound effects... custom audio planned later"). The `SoundEffectPlayer` wiring to attempt `TilePickup`/`TileDrop` playback exists in the working tree but is **uncommitted**, and the sound files themselves don't exist yet regardless.

### Two real bugs found and fixed along the way (both worth knowing about even though neither was the final blocker)

1. **Loudness**: the first shipped word-sound batch used `ffmpeg`'s `loudnorm` filter (LUFS-based integrated loudness normalization). `loudnorm` is unreliable on sub-second one-shot clips — it needs several seconds of audio to converge and produced clips around −19 dB mean / −6 dB peak, which is much quieter than it should be. Fixed by switching to straightforward peak normalization (measure the clip's true peak via `volumedetect`, then apply a `volume=+XdB` gain to bring the peak to −1 dBFS) applied *after* fades are baked in. **Takeaway: never use `loudnorm` on short one-shot game-audio clips — peak-normalize instead.**
2. **`CFBundleVersion` always "1"**: every CI build all session (including the entire visual-redesign/haptics era) produced an app with an identical version number, because `project.yml`'s `info.properties` never declared `CFBundleVersion`/`CFBundleShortVersionString` as `$(...)` placeholders, so xcodegen baked literal `"1"`/`"1.0"` strings into the generated `Info.plist` at project-generation time. A later attempt to fix this by passing `CURRENT_PROJECT_VERSION=${{ github.run_number }}` as an `xcodebuild` command-line override (in `.github/workflows/wordbitesapp-build.yml`) had no effect — confirmed via CI logs that the build *setting* was correctly overridden, but Xcode had nothing to substitute it into, since the Info.plist held a literal string, not a placeholder. Fixed by explicitly adding `CFBundleShortVersionString: "$(MARKETING_VERSION)"` and `CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"` to `project.yml`'s `info.properties`. Verified afterward by unzipping a fresh CI `.ipa` and reading its actual `Info.plist` (`CFBundleVersion` correctly showed the CI run number). **This was a real, generally-useful infrastructure fix, but it turned out not to be the actual cause of the "nothing ever updates" complaint below — that was something else entirely.**

### The actual "nothing ever updates" root cause — a delivery-mechanism bug, not a code bug

After multiple rounds of "I still can't hear anything" despite verified-correct resource bundling, verified-present compiled code, and a full delete-and-reinstall on the user's phone, the user suggested checking whether the `.ipa` file in their Downloads folder was actually being updated. It wasn't: `C:\Users\riddh\Downloads\WordBitesApp.ipa` had a last-modified date of **August 3**, from the very first AltStore release, days before any of this session's sound-effect work even started. Every `.ipa` sent during this session via the chat's own file-delivery mechanism (`SendUserFile`) had been landing somewhere else — never overwriting that specific file — so every "new" build the user tested by pointing AltServer at their Downloads folder was actually the same days-old build regardless of what had actually shipped.

**Fix / established workflow going forward**: this environment has direct local filesystem access to the user's actual machine (it is not a remote sandbox) — after downloading a CI build artifact, `cp` it directly to `C:\Users\riddh\Downloads\WordBitesApp.ipa`, overwriting in place, in addition to (or instead of) using `SendUserFile`. This is now the reliable way to get a build in front of the user for on-device testing. **If sideload testing ever again produces "no change no matter what," check this first before assuming a code bug.**

Once this was fixed, the shipped wind-chime word sounds were confirmed audible — which is when the conversation shifted from "I can't hear anything" to "I don't like how it sounds."

### Reference-audio analysis (the user's WhatsApp video of real Word Bites gameplay)

The user sent a ~7.75s video of themselves playing the actual Word Bites app, containing real tile-pickup/drop sounds and four word-scored sounds (words LIN/LINE/LINER/LINERS — conveniently exercising all 4 length tiers). This was analyzed in depth:

- **Timestamps identified** by running `ffmpeg silencedetect` on the extracted audio track, then extracting video frames at each candidate timestamp and visually confirming against the game's own on-screen "Words:"/"Score:" HUD and the word-highlight-white animation which word/event each sound corresponded to.
- **Word-scored sound structure** (established via *time-resolved* spectral analysis — multiple FFT snapshots across each clip's duration, not a single average): each sound is **two layered elements**, not one tone:
  1. A quick, low, broadband "click" — fundamental measured at 495 Hz (3-letter) / 522 Hz (4-letter) / 554 Hz (5-letter) / ~620 Hz (extrapolated for 6+), decaying away within roughly 60–80ms.
  2. A much higher "ring" that fades in right as the click dies out (~50–60ms in) and dominates the rest of the clip's sustain — measured at a strikingly consistent **6.0× the click's fundamental** across every tier (2972 / 3144 / 3316 / 3531 Hz — ratios 6.00, 6.02, 5.99). This is what actually carries the perceived pitch/ring of the sound; the low click is just the attack transient.
  - Total clip durations matched the original spec's "ascending duration per tier" almost exactly: 0.49s / 0.57s / 0.60s / 0.80s.
- **Tile pickup/drop sounds**: two very short (~50–60ms) broadband percussive blips, with two different spectral centroids measured (~488 Hz "duller" and ~1437 Hz "brighter"). Which one is pickup vs. drop was **not** definitively established from the video frames (ambiguous at that resolution/frame rate) — current code guesses brighter = pickup, duller = drop; this is an easy swap if it turns out backwards.

### The copyright determination (a hard boundary established this session, revisited multiple times)

The user repeatedly pushed to just use the extracted reference-video audio directly in the app (initially believing it "is not copyrighted whatsoever"; later asking to use it with modifications "so copyright is not a problem"; separately sending a zip of pre-extracted clips — verified via spectral fingerprint comparison to be the exact same reference-video audio, just re-trimmed — under a new framing). Every version of this was declined, on the same grounds each time:

- Word Bites is a commercial game; its sound assets are copyrighted by default the instant they were created, with no registration needed and no relevance to whether the game is free-to-play.
- The user recording their own gameplay on video doesn't transfer or waive the original developer's rights to the embedded audio.
- **Modifying a copyrighted recording does not remove copyright protection.** Pitch-shifting, time-stretching, trimming, or otherwise transforming a copyrighted recording creates a "derivative work," and the right to make derivative works is itself one of copyright's specifically protected exclusive rights — this is well-established in music sampling law and is not a gray area.
- This app is an explicit clone of Word Bites being distributed to other people (friends, via AltStore), which makes embedding the original's actual proprietary audio inside it particularly clear-cut, not a border case.
- **What is legitimate, and what this session's later work relied on**: analyzing the reference clip to extract *facts* — pitch values, timing, envelope/layering structure — and using those facts to build or source *independently-created* audio. Facts and technique aren't copyrightable; the specific recorded performance is. If this comes up again, this reasoning doesn't need to be rediscovered — it's settled for this project.

### Audio-synthesis/sourcing iteration history (context/audit trail — none of this is committed except the shipped v1)

All intermediate audio files below exist only in this session's WSL scratch directories (`~/audio/...` on the WSL side) and were sent to the user via chat for listening — **none were ever copied into `WordBitesApp/Sources/WordBitesApp/Resources/` or committed**, except the original wind-chime batch (v1, described above, which is what's currently live). If picking this up cold, none of this needs to be reconstructed from scratch — it's context for *why* certain approaches were tried and rejected, so they aren't retried blindly:

- **v1 (shipped)** — WindChime1 (real recording) pitch-shifted into a C5/E5/G5/C6 arpeggio. Audible and functional; tone rejected by the user as not fitting.
- **Tile-sound synthesis attempt 1** — fully synthesized (bandpass-filtered noise "click" + sine "thump", both with exponential decay), ~160–260ms durations. Sent for listening; user reported not being able to hear them at all (later determined this was likely chat-preview playback swallowing very short clips, not a broken file — but was never re-confirmed since strategy changed).
- **Word-sound synthesis attempt 2** — pure sine-wave "marimba" additive synthesis (fundamental + 2 inharmonic bar-mode overtones at ~2.76×/5.4× ratios), tuned from a *single-snapshot* (non-time-resolved) spectral read of the reference. Rejected by the user as "so plain, basic, just one note."
- **Word-sound synthesis attempt 3 (layered, still sine-based)** — synthesized mallet layer + WindChime1 pitched a fifth (1.5×) above it. Superseded before explicit feedback was given, once the deeper time-resolved analysis (see above) revealed the real structure wasn't a fifth-interval relationship at all, but a 6.0× one with a delayed onset.
- **Word-sound synthesis attempt 4** — same two-layer/6.0×-ratio/delayed-onset structure as the real measured reference, but both layers still synthesized/sourced as before (mallet = sines, ring = WindChime1 pitched way up). Verified programmatically (envelope shape matches the reference's "click, dip, bloom, sustain, decay" pattern) but not yet confirmed by ear.
- **Word-sound synthesis attempt 5 (current/latest)** — same structure, but **both layers now sourced from real instrument recordings** instead of synthesized tones: click layer = "Woodblock Drum @MRSTOKES302" (Pixabay, real recorded hit) pitched down to each tier's measured fundamental; ring layer = "Triangle Delay @MRSTOKES302" (Pixabay, real recorded triangle) pitched to 6× that fundamental, delayed onset. Sent to the user for listening. **No response received before this document was written — pick up here.**
- **Tile-sound synthesis attempt 2** — recalibrated bandpass-noise-click + sine-thump synthesis to match the *actual measured* reference timing/frequencies (~50–130ms, ~1450Hz-centroid "pickup" / ~620Hz-centroid "drop", up from the first attempt's guessed ~160-260ms/2600Hz/1700Hz), plus lead-in silence padding so short clips survive chat-preview playback. Sent for listening; **no response received.**

### What's actually needed to finish this

1. Get explicit approval on a word-sound direction (attempt 5, real recordings, is the most recent and most reference-faithful — but unconfirmed) and a tile pickup/drop direction (attempt 2 of that line, also unconfirmed).
2. Once approved: copy the final `.wav` files into `WordBitesApp/Sources/WordBitesApp/Resources/` as `WordSound3.wav`/`WordSound4.wav`/`WordSound5.wav`/`WordSound6.wav`/`TilePickup.wav`/`TileDrop.wav` (overwriting the current shipped word sounds if the direction changed).
3. Commit the currently-uncommitted `SoundEffectPlayer.swift` + `FeedbackPlayer.swift` changes (the `WordSoundPlayer.swift` deletion is part of the same diff).
4. Build via CI, verify the resulting `.ipa`'s bundle actually contains the new `.wav` files (unzip and check — this has silently failed before), then deliver via **both** `SendUserFile` **and** a direct `cp` overwrite of `C:\Users\riddh\Downloads\WordBitesApp.ipa` (see the delivery-mechanism note above — don't rely on `SendUserFile` alone).

## Visual redesign (design handoff "4a")

Unchanged since the previous handoff — implemented in full in an earlier session, no changes this session. Key facts worth knowing if extending this further:

- **Palette**: light parchment gradient page backgrounds (`#F6EFDD`→`#E9DCBC`), a deeper-tan gradient + dotted texture for the game screen, wood-grain gradient tiles (`#F5DFB8`/`#E9C68E`/`#F3D8AC`/`#E2BA80`, 135° diagonal), dark ink text (`#3B2A1E` primary), gold accent (`#D9B23F`→`#B08E2E`). Full token list is in `Theme.swift`.
- **Typography**: Archivo (Google Font) replaces Georgia everywhere except small uppercase labels, which stay on SwiftUI's `.system` font per the spec.
- **Font bundling detail worth preserving**: Archivo has no static per-weight files on Google Fonts — only one variable font (`Archivo[wdth,wght].ttf`, bundled at `WordBitesApp/Sources/WordBitesApp/Resources/Archivo.ttf`, registered via `UIAppFonts` in `project.yml`). Usable PostScript names are prefixed **`ArchivoRoman-`**, not `Archivo-` (e.g. `ArchivoRoman-Medium`, `ArchivoRoman-SemiBold`, `ArchivoRoman-Bold`).
- The redesign was visual/layout only — no `WordBitesKit` or game-logic changes.

## Distribution

The app has no paid Apple Developer Program enrollment. Distribution to other people is via **AltStore sideloading**:

- A **GitHub Release** (tag `sideload-v1.0`) hosts the built `.ipa` as a permanent, unauthenticated download URL.
- `altstore-source.json` at the repo root is the AltStore "source" file, publicly fetchable at `https://raw.githubusercontent.com/Rohit-Mahtani/word-bites/master/altstore-source.json`. App name in this file updated to "Aligned" this session (was "Aligners"). **Still points at the original `sideload-v1.0` release/version `1.0`** — no new version has been published to the AltStore source since this session's work began; every `.ipa` built this session was delivered ad hoc (via `SendUserFile` and/or direct Downloads-folder overwrite, see "Sound effects" above), not via an AltStore-source update. Publishing a new release/version bump has been explicitly deferred by the user ("not yet") pending the sound-effects work being finished.
- **To ship an update to everyone who's added the source** (not yet done this session): build the new `.ipa`, create a new GitHub Release asset (or update the existing one), then bump `altstore-source.json`'s `version`/`versionDate`/`versionDescription`/`downloadURL`/`size`/`sha256` and prepend a new entry to `versions[]`, commit, push.
- Each person still needs AltStore + AltServer themselves (their own free Apple ID), with the same 7-day free-Apple-ID re-signing limitation as the user's own install.
- Other options discussed but not implemented: ad-hoc distribution, TestFlight, full App Store listing (all require the $99/yr Developer Program).

## Build/CI

- `.github/workflows/wordbiteskit-tests.yml` — triggers on changes under `WordBitesKit/**`; runs `swift build`, `swift test`, CLI demo, on `macos-latest`. Unchanged this session.
- `.github/workflows/wordbitesapp-build.yml` — triggers on changes under `WordBitesApp/**` or `WordBitesKit/**`; runs `xcodegen generate`, `xcodebuild`, packages an unsigned `.ipa`, uploads as artifact `WordBitesApp`. **Changed this session**: the `xcodebuild` invocation now passes `CURRENT_PROJECT_VERSION=${{ github.run_number }}` so every CI build gets a distinct build number (see "Sound effects" → the `CFBundleVersion` bug above for why this matters and what else was needed to make it actually take effect).
- `WordBitesApp/project.yml` — xcodegen project definition. **Changed this session**: `info.properties` now explicitly declares `CFBundleShortVersionString: "$(MARKETING_VERSION)"` and `CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"` (previously undeclared, causing xcodegen to bake literal `"1.0"`/`"1"` into the generated Info.plist regardless of build settings). `CFBundleDisplayName` updated to `"Aligned"`. Otherwise unchanged: iOS 16 deployment target, local `WordBitesKit` package dependency, bundle ID `com.rohitmahtani.wordbites`, iPhone-only, `UIAppFonts: ["Archivo.ttf"]`.

## Local development environment notes

- No Mac available, ever. WSL2 Ubuntu with a separately-built Swift toolchain is used for all `swift build`/`swift test` runs (see the previous handoff's exact `PATH`/`LD_LIBRARY_PATH` setup — unchanged).
- **WordBitesApp (SwiftUI) has never been compiled locally at all** — every UI change is verified only by pushing and waiting for `xcodebuild` on GitHub Actions.
- **This environment has direct local filesystem access to the user's actual Windows machine** — it is not a remote sandbox. This matters concretely for `.ipa` delivery: see the Downloads-folder note under "Sound effects" above.
- A static `ffmpeg`/`ffprobe` build was downloaded to `~/bin/` in WSL this session (no root/sudo available for `apt-get install ffmpeg`; used the static build from `johnvansickle.com/ffmpeg/releases`) — this is the toolchain behind all the audio work described above (pitch-shifting via `asetrate`/`aresample`, synthesis via `anoisesrc`/`sine` lavfi sources, spectral analysis via small hand-written pure-Python FFT scripts since no Mac/fonttools/numpy-equivalent tooling is available either).
- **A recurring shell gotcha worth knowing**: multi-line `bash -lc '...'` commands containing `$VAR` references and `for` loops, when invoked through this environment's `wsl bash -lc` wrapper, unreliably fail to expand variables (symptoms: empty output, "command not found" for what should be a variable's expanded value). The reliable workaround used throughout this session: write the script to a `.sh` file first (via the `Write` tool), then invoke `wsl bash -lc 'bash "/mnt/c/.../script.sh"'` — never inline multi-line scripts directly in the `wsl bash -lc` argument.
- AltServer and AltStore are installed (Windows + the user's iPhone) for sideloading, using the user's free Apple ID.

## Known open items

- **Sound effects are unfinished** — see the full "Sound effects" section above. Immediate next step: get the user's verdict on the latest word-sound batch (real wood-block + triangle recordings, two-layer/6×-ratio structure) and the latest tile pickup/drop batch, then commit + bundle + ship whichever lands.
- The `SoundEffectPlayer.swift`/`FeedbackPlayer.swift` refactor (generalizing from word-only to word+tile sound support) is **uncommitted** in the working tree as of this writing.
- Archivo font rendering and the floating-HUD/centered-board layout were shipped in an earlier session but were never explicitly confirmed by the user as looking correct on-device (this predates the current session and was never revisited).
- The AltStore source (`altstore-source.json`) has not been updated to point at any build from this session — still serves the original `sideload-v1.0`/version `1.0` release. Needs a version bump once the sound-effects work lands and the user is ready to publish.
- If distribution ever needs to go beyond AltStore (TestFlight/App Store), the naming/branding closeness to the original "Word Bites" game hasn't been legally reviewed.

## Version control state

Latest commits on `master` (most recent first, as of this handoff):
- `a09313c` — Fix Info.plist version placeholders so build-number overrides actually apply
- `508ebff` — Auto-increment build number on every CI build
- `b748cf5` — Rename in-app text from Aligners to Aligned
- `c092e51` — Move sound diagnostic to an unconstrained debug overlay *(superseded — the diagnostic overlay this commit added was fully removed again in the current uncommitted working-tree changes; see below)*
- `582f596` — Switch WordSoundPlayer to contentsOf: and add temporary on-screen diagnostic *(diagnostic since removed, contentsOf: switch retained inside the current SoundEffectPlayer)*
- `288c892` — Fix inaudible word-scored sounds: peak-normalize instead of LUFS loudnorm
- `36fb495` — Add pitched chime sound effects for word scoring
- `62bcbcf` — Add project handoff document (the previous version of this file)
- (earlier history unchanged — see previous handoff revisions for the full list back to initial scaffolding)

**Uncommitted working-tree changes as of this writing** (not yet committed — see "What's actually needed to finish this" above):
- Modified: `FeedbackPlayer.swift` (wires `SoundEffectPlayer` calls into `wordScored`/`tilePickedUp`/`tilePlaced`)
- Deleted: `WordSoundPlayer.swift` (superseded by `SoundEffectPlayer.swift`)
- New/untracked: `SoundEffectPlayer.swift`
- `GameView.swift`/`GameViewModel.swift` currently show **no diff** against the last commit — a temporary diagnostic added mid-session was fully added and then fully removed within the same uncommitted working-tree state, netting to zero change.

The most recent CI runs for both workflows succeeded as of the last push (`a09313c`). There is also a separate `sideload-v1.0` release tag (not a branch) hosting the distributable `.ipa` — **stale**, does not reflect any work from this session (see "Distribution" above).
