# Agents.md

**Quick-start for new agents working on latex-tools.nvim**

This Neovim plugin accelerates LaTeX authoring for school assignments. Core value: course-aware assignment generation plus interactive helpers for figures, tables, references, citations, footnotes, CSV tables, and reusable `.tex` snippets.

## Project Layout

- `lua/latex-tools/` — All Lua source (entrypoint: `init.lua`)
  - `init.lua` — Public API + `setup()`
  - `config.lua` — User options (keymaps, commands, path overrides)
  - `state.lua` — Path resolution (user `~/.config/nvim/latex-tools/*` preferred over bundled `templates/`)
  - `assignment.lua` — Course picker + Python-driven template rendering
  - `templates.lua` — Document template discovery, metadata parsing, and unified picker
  - `figures.lua` / `tables.lua` — Interactive snippet builders (UI select + input)
  - `references.lua` — Label/`\ref` picker + BibTeX key picker (parses `.bib` and buffer labels)
  - `snippets.lua` — Pre-canned Python/R/SQL `lstlisting` blocks
  - `tex_snippets.lua` — Recursive picker for user-managed `.tex` snippets
  - `util.lua` — Shared helpers (insertion, escaping, CSV parsing, slugify, file listing)
  - `commands.lua` — `:LatexTools*` user commands
  - `keymaps.lua` — `\<prefix>` mappings (default `\t`) + which-key integration
  - `tests.lua` — `:LatexToolsTest` wrapper
- `python/render_template.py` — YAML parser and LaTeX command replacement for `assignment.tex`
- `templates/` — Bundled defaults (`courses.yaml`, `assignment.tex`)
- `.github/workflows/` — CI on pushes/pull requests and tagged GitHub releases
- `tests/templates_spec.lua` — Comprehensive headless regression suite (uses `nvim --headless -l`)

## Key Conventions

- **Paths**: `state.get_paths()` resolves bundled assets from `templates/`, user course/template files from `stdpath("config")/latex-tools/`, and custom snippets from `stdpath("config")/latex-tools/snippets/`. Respect configured path overrides.
- **User files**: `:LatexToolsInit` creates course metadata, document templates under `latex-tools/templates/`, and the snippets directory. `:LatexToolsInit!` overwrites the course and template starter files but never removes snippets. Personal data lives in user `courses.yaml` under `academic_profile`.
- **Insertion**: Prefer `util.insert_lines_at_cursor()` for blocks, `util.insert_inline_text_at_cursor()` for inline. `util.insert_template_lines()` for full documents.
- **Escaping**: Always use `util.escape_latex_text()` (or Python equivalent) for user content.
- **UI**: `vim.ui.select()` for pickers, `vim.fn.input()` for prompts. Stub them in tests.
- **Python**: Called via `state.get_python_cmd()` + `state.run_command()`. Supports PyYAML if available; falls back to the custom parser in `render_template.py`.
- **Testing**: Run with `:LatexToolsTest`, `\\tT`, or `nvim --headless -u NONE -l tests/templates_spec.lua`. Tests heavily stub `vim.fn.input`, `vim.ui.select`, `vim.fn.stdpath`, etc.
- **Style**: Keep modules small and single-purpose. No global state beyond config. Use `vim.notify()` for feedback. Follow existing comment style (short, factual).

## Common Tasks

**Add a new snippet/command/keymap**
1. Implement in appropriate module (e.g. `newfeature.lua`).
2. Expose via `init.lua` public API.
3. Register in `commands.lua` and `keymaps.lua`.
4. Add test case in `templates_spec.lua`.
5. Update README.md Commands/Keymaps sections and the `Unreleased` section of `CHANGELOG.md`.

**Change template rendering**
- Edit `templates/assignment.tex` (commands like `\newcommand{\AssignmentTitle}{...}`).
- Mark course-aware templates with `% latex-tools: course-aware` near the top of the file.
- Update Python `render_template()` metadata dict + `set_command_value()`.
- Extend `courses.yaml` schema if needed (update parser + tests).

**Add a document template**
- Add a `.tex` file under `templates/` for bundled defaults or the user `latex-tools/templates/` directory for personal templates.
- Use `% latex-tools: course-aware` only when the template should run through the Python renderer and course picker.

**Extend course metadata**
- Modify `parse_yaml_fallback()` and `list_courses()` / `render_template()` in Python.
- Keep YAML structure compatible with both PyYAML and fallback.

**Path or config change**
- Update `state.default_paths()` and `config.lua` defaults.
- Ensure tests pass with both user-config and bundled fallbacks.

**Custom `.tex` snippets**
- Store user snippets under `state.get_paths().custom_snippets_dir`; the default is `stdpath("config")/latex-tools/snippets`.
- `tex_snippets.lua` discovers `.tex` files recursively, displays paths relative to the snippets directory, and inserts the selected file with `util.insert_lines_at_cursor()`.
- Keep built-in Python/R/SQL snippets in `snippets.lua`; `\tx` is reserved for user-managed file snippets.

## Development Commands

```bash
# Run full test suite (canonical)
nvim --headless -u NONE -l tests/templates_spec.lua

# In-Neovim
:LatexToolsTest
\ tT
```

**Setup for development** (Lazy.nvim):
```lua
{ "ingiestein/latex-tools.nvim", config = function() require("latex-tools").setup({}) end }
```

For local development, replace the repository string with `dir = "~/Documents/GitHub/latex-tools.nvim"`.

The CI workflow runs the headless test suite on pushes to `main`/`master` and pull requests. The release workflow runs when a `v*` tag is pushed, reruns the tests, and creates a GitHub Release. Keep release tags and the version in `CHANGELOG.md` aligned.

See `README.md` for full setup, options, commands, keymaps, and user-file locations.

**Always run the test suite before finishing work.** It exercises every major code path, including custom snippet insertion, initialization, edge cases, and state preference logic.

This file is the single source of truth for agent context. Keep it up-to-date when architecture changes.
