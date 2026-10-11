# Inkwell

A notes app where you handwrite words on a strip at the bottom of the screen.
Each word is recognized on-device (Apple Vision), set in Newsreader, and floats
up into place in the note. Input is handwriting; the note reads as typography.

## Run it

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Inkwell.xcodeproj
```

Put your signing team in `Config/Local.xcconfig` (gitignored, survives
`xcodegen generate`):

```
DEVELOPMENT_TEAM = YOURTEAMID
```

Then run on a device or simulator
(iOS 17+). In the simulator, draw with the mouse.

## How it works

- `WritingStrip` – PencilKit canvas (finger or Pencil). A short pause ends a word. Drag the handle above it to expand the strip.
- `Tuning` – pause length, strip size and other feel constants in one place.
- `InkRecognizer` – renders the strokes dark-on-white (at two ink thicknesses) and runs `VNRecognizeTextRequest`.
- `WordCorrector` – picks the reading made of real words and repairs near-miss spellings with the system dictionary.
- `NotesLibrary` / `NotesListView` – the home screen listing saved notes. The editor's back button returns to it.
- `NoteStore` – one note as a list of words, saved as JSON in Documents/Notes.
  Lone punctuation attaches to the previous word; sentence starts are capitalized.
- `WordView` – the float-up animation, from the strip's center to the word's slot.
- `FlowLayout` – lays words out like wrapped text.
- Tap any word to correct it. Use the strip's buttons to delete the last word or clear the note.

## Fonts

Newsreader (SIL OFL, see `Inkwell/Resources/Fonts/OFL.txt`).
