# Changelog

## Unreleased

### Added

- Added a picker for user-managed `.tex` snippets, available through `:LatexToolsSnippet` and `\\tx`.
- Added `:LatexToolsInitSnippets` to create the snippets directory and `:LatexToolsInit[!]` to set up snippets, course metadata, and the assignment template together.
- Added configuration for a custom snippets directory through `paths.custom_snippets_dir`.

### Documentation

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
