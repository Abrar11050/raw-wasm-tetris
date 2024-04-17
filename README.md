# Raw WebAssembly Tetris

WebAssembly Tetris for browser. Rather than using any high-level programming language, this one is implemented by hand in raw WASM text (*.wat), well, most of it. In around ~600 lines of code.

### What're **not** implemented in WASM:
* Input handling
* Presentation Logic
* Random Number Generation
### What're implemented in WASM:
* Everything Else! (Including but not limited to: collision detection, row elimination, score increment, piece spawning, resetting etc.)

The piece property (shape, color) encoding mechanism is explained in details in the [pieces.md](supplementary/pieces.md) file.

A [pseudocode file](supplementary/pseudocode.c), written in C-like syntax is supplied as an explanation of the WASM code, with comments. Please note that this code won't compile and is only provided for understanding purposes.

## Presentation Frontend : Canvas (default)

``./videos/tr_canvas.mp4``

## Presentation Frontend : ASCII

``./videos/tr_ascii.mp4``

## Building and Running

* Download and Install [WABT](https://github.com/WebAssembly/wabt)
* Clone this Repo
* Assemble the source:
```bash
wat2wasm tetris.wat
```
* Or if you want to preserve debug symbols:
```bash
wat2wasm --debug-names tetris.wat
```
* Make sure the ``tetris.wasm`` file is generated
* Launch an HTTP server from current working directory, like:
```bash
python -m http.server # use python3 for Linux
```

## Controls

* <kbd>←</kbd> Move Left
* <kbd>→</kbd> Move Right
* <kbd>↓</kbd> Move Down Fast (Instant Drop not Supported, So Hold Key to Drop)
* <kbd>Space</kbd> Rotate Piece
* <kbd>P</kbd> Play/Pause Toggle
* <kbd>R</kbd> Restart