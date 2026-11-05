# lilypond-forward-search.nvim

Forward search (Neovim → PDF) for LilyPond, without SyncTeX. Uses the `textedit://` links that LilyPond embeds in the PDF, extracted with PyMuPDF, and sends them to Zathura via D-Bus.

No patched viewers, no `.synctex` files, no external indexers. Just the links LilyPond already writes and a D-Bus call.

## Features

- **Forward search** (Neovim → PDF): jump from the cursor to the exact note in the PDF, with a visible highlight.
- **Multiple PDFs**: choose which `\book` output to display when a single `.ly` produces several PDFs.
- **Multi-file projects**: compile from any `\include` using a `% master: main.ly` comment at the top of the file.
- **Follow mode**: automatically sync the PDF as you move the cursor.

## Requirements

- Neovim (0.9+)
- [nvim-lilypond-suite](https://github.com/martineausimon/nvim-lilypond-suite)
- [Zathura](https://pwmt.org/projects/zathura/) with D-Bus enabled
- Python 3 with [PyMuPDF](https://pymupdf.readthedocs.io/)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "fsarud/lilypond-forward-search.nvim",
  dependencies = { "martineausimon/nvim-lilypond-suite" },
  ft = { "lilypond", "tex", "texinfo" },
  opts = {},
}
```

## Configuration and Usage

Default options (all optional):

```lua
{
  "YOUR-USER/lilypond-forward-search.nvim",
  opts = {
    keymaps = {
      compile = "<F5>",
      index = "<F7>",
      select_pdf = "<F8>",
      forward_search = "<F9>",
      toggle_follow = "<F10>",
    },
    follow = {
      enabled = false,
      debounce_ms = 50,
    },
    margin = 5.0,
  },
}
```

## Usage

| Key | Action |
|-----|--------|
| F5  | Compile (respects `% master: file.ly`) |
| F7  | Regenerate index for the active PDF |
| F8  | Choose PDF (when multiple `\book` outputs exist) |
| F9  | Forward search: cursor → PDF |
| F10 | Toggle follow mode |

## Multi-file projects

If your main file is in a different directory (or you want to compile from an `\include`), add a comment at the top of the included file:

```lilypond
% master: main.ly
\version "2.26.0"
```

F5 will compile `main.ly` instead of the current buffer.

## How it works

LilyPond embeds hyperlinks with URIs of the form `textedit:///absolute/path/file.ly:line:col:endcol` in the generated PDF. This plugin:

1. Extracts those links with PyMuPDF (`page.get_links()`).
2. Builds a JSON index mapping `(file, line, col)` to `{page, rect}`.
3. On F9, looks up the cursor position in the index and sends the rectangle to Zathura via the `HighlightRects` D-Bus method.

No SyncTeX, no patched viewers. Just the data LilyPond already provides.

## Status

- Forward search: done
- Multiple PDFs: done
- Multi-file projects (`% master:`): done
- Follow mode: done
- Inverse search (PDF → Neovim): already tackled by lilypond-neovim-suite

## License

MIT
