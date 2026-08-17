# Agents.md

**Quick-start for new agents working on latex-tools.nvim**

This Neovim plugin accelerates LaTeX authoring for graduate school assignments. Core value: course-aware assignment templates + interactive helpers for figures, tables, references, citations, footnotes, and code listings.

## Project Layout

- `lua/latex-tools/` — All Lua source (entrypoint: `init.lua`)
  - `init.lua` — Public API + `setup()`
  - `config.lua` — User options (keymaps, commands, path overrides)
  - `state.lua` — Path resolution (user `~/.config/nvim/latex-tools/*` preferred over bundled `templates/`)
  - `assignment.lua` — Course picker + Python-driven template rendering
  - `figures.lua` / `tables.lua` — Interactive snippet builders (UI select + input)
  - `references.lua` — Label/`\ref` picker + BibTeX key picker (parses `.bib` and buffer labels)
  - `snippets.lua` — Pre-canned Python/R/SQL `lstlisting` blocks
  - `util.lua` — Shared helpers (insertion, escaping, CSV parsing, slugify, file listing)
  - `commands.lua` — `:LatexTools*` user commands
  - `keymaps.lua` — `\<prefix>` mappings (default `\t`) + which-key integration
  - `tests.lua` — `:LatexToolsTest` wrapper
- `python/render_template.py` — YAML parser + Jinja-like command replacement for `assignment.tex`
- `templates/` — Bundled defaults (`courses.yaml`, `assignment.tex`)
- `tests/templates_spec.lua` — Comprehensive headless regression suite (uses `nvim --headless -l`)

## Key Conventions

- **Paths**: `state.get_paths()` respects user config first (`stdpath("config")/latex-tools/*`), falls back to plugin `templates/`. Use it everywhere.
- **User files**: Encourage `:LatexToolsInitCourses` and `:LatexToolsInitAssignment` (with `!` to overwrite). Personal data lives in user `courses.yaml` under `academic_profile`.
- **Insertion**: Prefer `util.insert_lines_at_cursor()` for blocks, `util.insert_inline_text_at_cursor()` for inline. `util.insert_template_lines()` for full documents.
- **Escaping**: Always use `util.escape_latex_text()` (or Python equivalent) for user content.
- **UI**: `vim.ui.select()` for pickers, `vim.fn.input()` for prompts. Stub them in tests.
- **Python**: Called via `state.get_python_cmd()` + `state.run_command()`. Supports PyYAML if available; falls back to custom parser.
- **Testing**: Run with `:LatexToolsTest`, `\\tT`, or `nvim --headless -u NONE -l tests/templates_spec.lua`. Tests heavily stub `vim.fn.input`, `vim.ui.select`, `vim.fn.stdpath`, etc.
- **Style**: Keep modules small and single-purpose. No global state beyond config. Use `vim.notify()` for feedback. Follow existing comment style (short, factual).

## Common Tasks

**Add a new snippet/command/keymap**
1. Implement in appropriate module (e.g. `newfeature.lua`).
2. Expose via `init.lua` public API.
3. Register in `commands.lua` and `keymaps.lua`.
4. Add test case in `templates_spec.lua`.
5. Update README.md Commands/Keymaps sections.

**Change template rendering**
- Edit `templates/assignment.tex` (commands like `\newcommand{\AssignmentTitle}{...}`).
- Update Python `render_template()` metadata dict + `set_command_value()`.
- Extend `courses.yaml` schema if needed (update parser + tests).

**Extend course metadata**
- Modify `parse_yaml_fallback()` and `list_courses()` / `render_template()` in Python.
- Keep YAML structure compatible with both PyYAML and fallback.

**Path or config change**
- Update `state.default_paths()` and `config.lua` defaults.
- Ensure tests pass with both user-config and bundled fallbacks.

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
{ dir = "~/Documents/GitHub/latex-tools.nvim", config = function() require("latex-tools").setup({}) end }
```

See `README.md` for full setup, options, and standalone repo extraction instructions.

**Always run the test suite before finishing work.** It exercises every major code path, including edge cases and state preference logic.

This file is the single source of truth for agent context. Keep it up-to-date when architecture changes.
