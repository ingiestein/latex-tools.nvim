# Agents.md

**Quick-start for new agents working on latex-tools.nvim**

This Neovim plugin accelerates LaTeX authoring for school assignments. Core value: a unified document-template picker (including course-aware assignment rendering), plus interactive helpers for figures, tables, references, citations, footnotes, CSV tables, and reusable `.tex` snippets.

## Project Layout

- `lua/latex-tools/` — All Lua source (entrypoint: `init.lua`)
  - `init.lua` — Public API + `setup()`; exposes `init_metadata`, `init_templates`, `init_snippets`, `init_all`
  - `config.lua` — User options (keymaps, commands, path overrides); warns on `python_script_path` override
  - `state.lua` — Path resolution, user-file bootstrapping, `run_command()` with sanitized errors
  - `templates.lua` — Document template discovery, `% latex-tools:` metadata parsing, unified picker
  - `subfiles.lua` — Subfile chapter creation from saved course-aware parent buffers
  - `assignment.lua` — Course picker + Python-driven rendering for course-aware templates
  - `figures.lua` / `tables.lua` — Interactive snippet builders (UI select + input)
  - `references.lua` — Label/`\ref` picker + BibTeX key picker (parses `.bib` and buffer labels)
  - `snippets.lua` — Pre-canned Python/R/SQL `lstlisting` blocks
  - `tex_snippets.lua` — Recursive picker for user-managed `.tex` snippet files
  - `util.lua` — Shared helpers (insertion, escaping, CSV parsing, slugify, file listing, date validation, message sanitization, template metadata)
  - `commands.lua` — `:LatexTools*` user commands
  - `keymaps.lua` — `\<prefix>` mappings (default `\t`) + which-key integration
  - `tests.lua` — `:LatexToolsTest` wrapper
- `python/render_template.py` — YAML parser and LaTeX command replacement for course-aware templates
- `templates/` — Bundled defaults (`courses.yaml`, `assignment.tex`, `subfile.tex`)
- `.github/workflows/` — CI on pushes/pull requests and tagged GitHub releases
- `tests/templates_spec.lua` — Comprehensive headless regression suite (uses `nvim --headless -l`)

## Key Conventions

- **Paths**: `state.get_paths()` resolves:
  - bundled assets from `templates/`
  - user metadata from `stdpath("config")/latex-tools/courses.yaml`
  - user document templates from `stdpath("config")/latex-tools/templates/`
  - custom snippets from `stdpath("config")/latex-tools/snippets/`
  - assignment rendering via `tex_template_path`, preferring `templates/assignment.tex`, then legacy `latex-tools/assignment.tex`, then bundled
  - Respect configured path overrides in `config.lua`.
- **User file initialization**:
  - `init_metadata(opts)` / `:LatexToolsInitMetadata[!]` — `courses.yaml` only
  - `init_templates(opts)` / `:LatexToolsInitTemplates[!]` — all bundled `.tex` files into user templates dir
  - `init_snippets()` / `:LatexToolsInitSnippets` — snippets directory only
  - `init_all(opts)` / `:LatexToolsInit[!]` — all of the above; `opts` may set `metadata`, `templates`, `snippets`, and `force` individually
  - `:LatexToolsInit!` overwrites metadata and templates but never removes snippets
  - Older names (`init_course_metadata`, `init_user_templates`, `init_user_files`, etc.) remain as aliases
- **Document templates vs snippets**:
  - Templates: full documents in `templates/*.tex`; inserted via `:LatexToolsTemplate` / `\ta`
  - Subfiles: created via `:LatexToolsSubfile` / `\tS` from a saved buffer containing `% latex-tools: course-aware`; writes `subfile/<name>.tex` beside the parent and opens it in a right split
  - Snippets: partial blocks in `snippets/**/*.tex`; inserted via `:LatexToolsSnippet` / `\tx`
  - Mark course-aware templates with `% latex-tools: course-aware` in the first ~20 lines; `subfile.tex` is bundled but excluded from the template picker
- **Insertion**: Prefer `util.insert_lines_at_cursor()` for blocks, `util.insert_inline_text_at_cursor()` for inline, `util.insert_template_lines()` for full documents.
- **Escaping**: Always use `util.escape_latex_text()` (or Python equivalent) for user content.
- **Validation**: Assignment due dates must pass `util.valid_date()` (`YYYY-MM-DD`, including leap years) before rendering.
- **UI**: `vim.ui.select()` for pickers, `vim.fn.input()` for prompts. Stub them in tests.
- **Python**: Called via `state.get_python_cmd()` + `state.run_command()`. Supports PyYAML if available; falls back to the custom parser in `render_template.py`. Command errors are sanitized with `util.sanitize_message()` before notification.
- **Testing**: Run with `:LatexToolsTest`, `\\tT`, or `nvim --headless -u NONE -l tests/templates_spec.lua`. Tests heavily stub `vim.fn.input`, `vim.ui.select`, `vim.fn.stdpath`, etc.
- **Style**: Keep modules small and single-purpose. No global state beyond config. Use `vim.notify()` for feedback. Follow existing comment style (short, factual).

## Common Tasks

**Add a new snippet/command/keymap**
1. Implement in appropriate module (e.g. `newfeature.lua`).
2. Expose via `init.lua` public API.
3. Register in `commands.lua` and `keymaps.lua`.
4. Add test case in `templates_spec.lua`.
5. Update README.md Commands/Keymaps sections and the `Unreleased` section of `CHANGELOG.md`.

**Add a subfile chapter**
- Parent buffer must contain `% latex-tools: course-aware` and be saved to disk.
- `subfiles.lua` prompts for a name, creates `subfile/` beside the parent, writes from bundled `subfile.tex`, substitutes the parent filename for `main.tex` / `../main`, and opens the result with `rightbelow vsplit`.

**Add a document template**
- Bundled default: add `templates/your-template.tex`.
- User-only: user drops file in `latex-tools/templates/`.
- Static templates need no code changes.
- Course-aware templates: add `% latex-tools: course-aware` near the top and ensure Python `render_template()` can fill the template's `\newcommand` placeholders.

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

**Custom `.tex` snippets**
- Store user snippets under `state.get_paths().custom_snippets_dir`; the default is `stdpath("config")/latex-tools/snippets`.
- `tex_snippets.lua` discovers `.tex` files recursively via `util.list_tex_files(directory, true)`, displays paths relative to the snippets directory, and inserts with `util.insert_lines_at_cursor()`.
- Keep built-in Python/R/SQL snippets in `snippets.lua`; `\tx` is reserved for user-managed file snippets.

**Change initialization behavior**
- Bootstrapping logic lives in `state.lua` (`initialize_course_metadata`, `initialize_user_templates`, `initialize_custom_snippets_dir`).
- Public orchestration lives in `init.lua` (`init_metadata`, `init_templates`, `init_snippets`, `init_all`).
- Template init copies all bundled `*.tex` files and emits one summary notification.

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

**Always run the test suite before finishing work.** It exercises every major code path, including template picking, custom snippet insertion, selective initialization, edge cases, and state preference logic.

This file is the single source of truth for agent context. Keep it up-to-date when architecture changes.
