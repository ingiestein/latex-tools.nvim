# latex-tools.nvim

Local Neovim plugin for reusable LaTeX authoring workflows.

Course metadata and the assignment template are best treated as user config, not plugin code. The plugin now prefers user-local files at `vim.fn.stdpath("config") .. "/latex-tools/courses.yaml"` and `vim.fn.stdpath("config") .. "/latex-tools/assignment.tex"`, and falls back to the bundled samples in `templates/` when those files do not exist.

Personal information belongs in the user-local `courses.yaml`, under `academic_profile`. The committed `templates/assignment.tex` file contains only generic placeholder values. Course-specific information belongs under `course_catalog`; assignment title and due date are entered when generating an assignment.

## Features

- Course-aware assignment template insertion
- Interactive and placeholder figure/table insertion
- Footnote insertion prompt
- Label/reference picker (ref/pageref/autoref)
- BibTeX key picker (cite/citep/citet)
- CSV-to-LaTeX table generation
- Headless regression test runner

## Setup (LazyVim)

This workspace already registers the plugin in:

- `lua/plugins/latex-tools.lua`

Configuration example:

```lua
return {
  {
    dir = vim.fn.stdpath("config") .. "/local-plugins/latex-tools.nvim",
    name = "latex-tools.nvim",
    opts = {
      keymaps = { enable = true, prefix = "\\t" },
      commands = { enable = true },
      paths = {
        -- Optional overrides. Plugin-local defaults are used when omitted.
        -- template_dir = vim.fn.expand("~/.config/latex-templates"),
        -- yaml_path = vim.fn.expand("~/.config/nvim/latex-tools/courses.yaml"),
        -- tex_template_path = vim.fn.expand("~/.config/nvim/latex-tools/assignment.tex"),
        -- python_script_path = vim.fn.expand("~/.config/latex-templates/render_template.py"),
        -- test_script_path = vim.fn.expand("~/.config/nvim/tests/templates_spec.lua"),
      },
      -- Optional interpreter override.
      -- python_cmd = vim.g.python3_host_prog,
    },
    config = function(_, opts)
      require("latex-tools").setup(opts)
    end,
  },
}
```

If the plugin lives outside your Neovim config directory, do not call `vim.fn.stdpath("~")`. Use `vim.fn.expand("~/...")` instead:

```lua
return {
  {
    dir = vim.fn.expand("~/Documents/GitHub/latex-tools.nvim"),
    name = "latex-tools.nvim",
    config = function(_, opts)
      require("latex-tools").setup(opts)
    end,
  },
}
```

## Setup Options

- `keymaps.enable` (boolean): enable plugin-provided keymaps.
- `keymaps.prefix` (string): keymap prefix, defaults to `\\t`.
- `commands.enable` (boolean): enable plugin-provided user commands.
- `paths.template_dir` (string|nil): optional directory override for template assets.
- `paths.yaml_path` (string|nil): optional override for course metadata YAML.
- `paths.tex_template_path` (string|nil): optional override for assignment template path.
- `paths.python_script_path` (string|nil): optional override for renderer script path.
- `paths.test_script_path` (string|nil): optional override for test suite path.
- `python_cmd` (string|nil): optional Python executable override.

When specific path overrides are omitted, plugin-local defaults are used.

For course metadata, the default lookup order is:

- `vim.fn.stdpath("config") .. "/latex-tools/courses.yaml"`
- bundled fallback at `templates/courses.yaml`

For the assignment template, the default lookup order is:

- `vim.fn.stdpath("config") .. "/latex-tools/assignment.tex"`
- bundled fallback at `templates/assignment.tex`

That makes `~/.config/nvim/latex-tools/courses.yaml` and `~/.config/nvim/latex-tools/assignment.tex` the recommended locations on macOS and Linux. `stdpath("data")` is better suited for generated or cached files; these are user-authored files and should live with config.

## Commands

- `:LatexToolsTest`
- `:LatexToolsInitCourses`
- `:LatexToolsInitAssignment`
- `:LatexToolsAssignment`
- `:LatexToolsFigure`
- `:LatexToolsFigurePlaceholder`
- `:LatexToolsTable`
- `:LatexToolsTablePlaceholder`
- `:LatexToolsFootnote`
- `:LatexToolsReference`
- `:LatexToolsBib`
- `:LatexToolsCSVTable`

## Public Lua API

- `require("latex-tools").setup(opts)`
- `require("latex-tools").get_config()`
- `require("latex-tools").init_course_metadata(opts)`
- `require("latex-tools").init_assignment_template(opts)`
- `require("latex-tools").insert_assignment_template()`
- `require("latex-tools").insert_figure_snippet()`
- `require("latex-tools").insert_basic_figure_snippet()`
- `require("latex-tools").insert_table_snippet()`
- `require("latex-tools").insert_basic_table_snippet()`
- `require("latex-tools").insert_footnote_snippet()`
- `require("latex-tools").insert_reference_snippet()`
- `require("latex-tools").insert_bib_key_snippet()`
- `require("latex-tools").insert_table_from_csv()`
- `require("latex-tools").insert_snippet(key)` where key is `p`, `r`, or `s`
- `require("latex-tools").run_tests()`

## Default Keymaps

Prefix defaults to `\\t`.

- `\\ta` assignment template picker
- `\\tf` figure picker
- `\\tF` placeholder figure
- `\\tb` interactive table
- `\\tB` placeholder table
- `\\tn` footnote prompt
- `\\tR` label reference
- `\\tk` BibTeX citation key
- `\\tv` table from CSV
- `\\tp` Python snippet
- `\\tr` R snippet
- `\\ts` SQL snippet
- `\\tT` run tests

## Notes

- By default, assets are plugin-local:
  - `local-plugins/latex-tools.nvim/templates/courses.yaml`
  - `local-plugins/latex-tools.nvim/templates/assignment.tex`
  - `local-plugins/latex-tools.nvim/python/render_template.py`
  - `local-plugins/latex-tools.nvim/tests/templates_spec.lua`
- Use `:LatexToolsInitCourses` to copy the bundled course metadata sample to your user config directory. Add `!` to overwrite an existing file.
- Use `:LatexToolsInitAssignment` to copy the bundled assignment template to your user config directory. Add `!` to overwrite an existing file.
- Python rendering uses `vim.g.python3_host_prog` when set, otherwise `python3`.

## Testing

- Canonical plugin-local test run:

```bash
nvim --headless -u NONE -l tests/templates_spec.lua
```

- In your existing Neovim setup, use:
  - `:LatexToolsTest`
  - `\\tT`

## Changelog

- See `CHANGELOG.md` for migration and release milestones.

## Standalone Repo Extraction

To split this local plugin into its own repository:

1. Create a new GitHub repo (for example `latex-tools.nvim`).
2. Copy the entire contents of this directory into that repo root.
3. Ensure the following remain at repo root:
  - `lua/latex-tools/*`
  - `templates/*`
  - `python/render_template.py`
  - `tests/templates_spec.lua`
  - `.github/workflows/ci.yml`
  - `.github/workflows/release.yml`
4. Push and tag a release, for example `v0.2.0`.
5. Update your Neovim plugin spec from local `dir = ...` to GitHub `"owner/latex-tools.nvim"`.

## Versioning

- Use semantic version tags: `vMAJOR.MINOR.PATCH`.
- Recommended initial public tag after this migration: `v0.2.0`.
