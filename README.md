# lilypond-forward-search.nvim

Forward search (Neovim → PDF) for LilyPond, without SyncTeX. Uses the
`textedit://` links that LilyPond embeds in the PDF, extracted with PyMuPDF,
and sends them to Zathura via D-Bus.

No patched viewers, no `.synctex` files, no external indexers. Just the
links LilyPond already writes and a D-Bus call.

## Features

- **Forward search** (Neovim → PDF): jump from the cursor to the exact note
  in the PDF, with a visible highlight.
- **Multiple PDFs**: choose which `\book` output to display when a single
  `.ly` produces several PDFs.
- **Multi-file projects**: compile from any `\include` using a
  `% master: main.ly` comment at the top of the file.
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
