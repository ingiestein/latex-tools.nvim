# Changelog

## Unreleased

- Added a unified document template picker through `:LatexToolsTemplate` and `\\ta`.
- Changed subfile workflow: use `:LatexToolsSubfile` / `\\tS` from a saved course-aware parent document instead of inserting `subfile.tex` into a blank buffer.
- Fixed subfile include insertion to use the pre-prompt cursor line so `\\subfile{...}` lands where the user invoked the command.
- Added `latex-tools/templates/` as the user document template directory, with legacy support for `latex-tools/assignment.tex`.
- Added template metadata via `% latex-tools: course-aware` so new rendered templates do not require code changes.
- Added due-date validation (`YYYY-MM-DD`) before assignment rendering.
- Summarized template initialization into a single notification instead of one message per file.
- Sanitized external command error output before showing notifications.
- Warn on setup when `paths.python_script_path` is overridden.
- Split init API into `init_metadata`, `init_templates`, `init_snippets`, and selective `init_all`.
- Documented the templates-vs-snippets distinction, security notes, and updated commands in `README.md`.

## 0.2.1

- Added a picker for user-managed `.tex` snippets, available through `:LatexToolsSnippet` and `\\tx`.
- Added `:LatexToolsInitSnippets` to create the snippets directory and `:LatexToolsInit[!]` to set up snippets, course metadata, and the assignment template together.
- Added configuration for a custom snippets directory through `paths.custom_snippets_dir`.
- Updated LazyVim installation instructions to use the GitHub plugin repository.

## 0.2.0

- Introduced plugin-native module namespace under lua/latex-tools.
- Added setup-driven command and keymap registration.
- Added plugin-local assets:
  - templates/assignment.tex
  - templates/courses.yaml
  - python/render_template.py
- Added plugin-local canonical test suite in tests/templates_spec.lua.
- Added CI workflow for headless Neovim tests.

## 0.1.0

- Initial LaTeX helper implementation for assignment templates.
- Added interactive snippet insertion for figures, tables, references, BibTeX keys, and CSV tables.

