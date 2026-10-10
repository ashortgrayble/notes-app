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

Set your signing team in Xcode, then run on a device or simulator
(iOS 17+). In the simulator, draw with the mouse.

## How it works

- `WritingStrip` – PencilKit canvas (finger or Pencil). A pause of ~0.9s ends a word.
- `InkRecognizer` – renders the strokes dark-on-white and runs `VNRecognizeTextRequest`.
- `NoteStore` – the note as a list of words, saved to `note.json`.
  Lone punctuation attaches to the previous word; sentence starts are capitalized.
- `WordView` – the float-up animation, from the strip's center to the word's slot.
- `FlowLayout` – lays words out like wrapped text.
- Tap any word to correct it. Use the strip's buttons to delete the last word or clear the note.

## Fonts

Newsreader (SIL OFL, see `Inkwell/Resources/Fonts/OFL.txt`).
