# Changelog

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
