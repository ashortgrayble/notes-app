# Handoff: Inkwell iOS prototype

Read this first. It was written by a cloud Claude session that had no Swift
toolchain, so **none of this code has ever been compiled or run.**

## The product

A notes app where you handwrite on a strip at the bottom of the screen. After a
short pause, the ink is recognized on-device, converted to the serif typeface
Newsreader, and floats up into its place in the note. Input is handwriting; the
final note reads as typography. **The writing strip and the float-up motion are
the main differentiator**, so protect that feel above all else.

Decisions already made by the owner:
- iOS only, native SwiftUI, iOS 17+ (Android maybe later)
- Apple Vision for handwriting recognition (`VNRecognizeTextRequest`)
- Newsreader for the note typeface
- Prototype first; the owner will refine the vision and feel as they go

## Branch

`prototype-writing-strip` (nothing is on `main` except the initial commit).

## Run it

```sh
brew install xcodegen
xcodegen generate
open Inkwell.xcodeproj
```

`project.yml` is the source of truth for the Xcode project; `*.xcodeproj` is
gitignored. Set a signing team (and change the bundle ID `com.example.inkwell`
if needed). Test on a real iPhone if possible: finger-drawing feel and
recognition accuracy can't be judged with a mouse in the simulator.

## Code map (`Inkwell/Sources`)

| File | Role |
|---|---|
| `InkwellApp.swift` | App entry; injects `NoteStore`, forces light mode |
| `ContentView.swift` | Note area + writing strip; `commit()` runs the ink -> recognize -> append pipeline and shows a fading "ghost" of the ink |
| `WritingStrip.swift` | `PKCanvasView` wrapper (finger or Pencil). A ~0.9s pause calls `onCommit(drawing, bounds)` and clears the canvas |
| `InkRecognizer.swift` | Renders strokes dark-on-white, runs Vision, returns text |
| `NoteStore.swift` | Words as `[Word]`, saved to `note.json`. Attaches lone punctuation to the previous word, capitalizes sentence starts |
| `WordView.swift` | The float-up animation: starts at the strip center (`launchPoint` environment value), blurred/small/transparent, springs to its slot |
| `FlowLayout.swift` | Custom `Layout` that wraps words like text |
| `Theme.swift` | Colors and `Theme.serif(...)`, which loads the Newsreader variable font and pins `wght`/`opsz` axes |

Fonts are in `Inkwell/Resources/Fonts` (OFL license included) and registered via
`UIAppFonts` in `project.yml`.

## Step 1: get it building and running (do this first)

1. Generate the project and build. Fix any compile errors with minimal changes;
   keep the architecture unless something is truly broken.
2. Run on a simulator, then ideally a device. Confirm you can draw, a word is
   recognized, and it animates into the note.
3. Commit fixes to `prototype-writing-strip` with clear messages.

## Things I'm unsure about (verify these)

- **Newsreader may not load.** It's a variable font. `Theme.serif` looks up the
  PostScript name `Newsreader16pt-Regular` (italic: `Newsreader16pt-Italic`) and
  sets `wght`/`opsz` through `kCTFontVariationAttribute`. If that lookup fails it
  silently falls back to the system serif. Check by printing
  `UIFont.fontNames(forFamilyName:)` and confirm the rendered text is
  Newsreader. If variable-axis handling is flaky, bundle static instances
  instead.
- **Recognition accuracy is the biggest product risk.** Vision text recognition
  is built for printed text; handwriting, single words and cursive can be poor.
  Try different ink widths, padding, image scale, and `usesLanguageCorrection`,
  and report honest accuracy findings. Tap-to-correct exists as a fallback.
- **Animation geometry.** `WordView` computes its start offset from its frame in
  the `"root"` coordinate space at `onAppear`, while the scroll view is also
  auto-scrolling. The word may land slightly off or visibly jump. Verify it looks
  right, especially when the note is long enough to scroll.
- **Ghost ink timing** in `ContentView.commit()` (ink lingers ~250ms then fades
  while the recognized word launches). Check it doesn't flicker or race when
  words are written quickly back to back.
- `NoteStore.append` marks a word `isFresh` so it animates; edits and loads
  don't. Make sure words never replay the animation unexpectedly.

## Step 2: tune the feel (then ask the owner)

Things the owner is likely to want to tweak; keep them easy to adjust
(constants in one place is fine):
- Pause before commit (`pauseBeforeCommit`, 0.9s)
- Spring (`response: 0.85, dampingFraction: 0.8`), blur and scale curve
- Strip height (170pt), ink width (4), paper colors, type size (26pt)

## Out of scope for now

Multiple notes, iCloud sync, rich text, Android, export. Don't add these
unprompted.

## Prompt to paste into the new session

> You're taking over an iOS prototype called Inkwell in this repo, on the branch
> `prototype-writing-strip`. Read `HANDOFF.md` first. The code was written
> without a compiler, so start by running `xcodegen generate`, building, and
> fixing any errors, then get it running in the simulator. Verify the specific
> risks listed in HANDOFF.md (Newsreader loading, recognition accuracy,
> animation placement) and tell me what you find. Commit fixes to the branch.
> Don't add features beyond what's listed without asking me.
