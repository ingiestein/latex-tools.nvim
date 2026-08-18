# latex-tools.nvim

Handy LaTeX helpers for Neovim: assignment files, figures, tables, references, citations, and your own reusable snippets.

Your course details, assignment template, and reusable snippets live in your Neovim config, not in the plugin. Custom snippets go in `vim.fn.stdpath("config") .. "/latex-tools/snippets"`.

Put personal details in `courses.yaml` under `academic_profile`, and add courses under `course_catalog`. The included assignment template uses generic placeholders; you choose the assignment title and due date when you create a document.

## Features

- Course-aware assignment template insertion
- Interactive and placeholder figure/table insertion
- Footnote insertion prompt
- Label/reference picker (ref/pageref/autoref)
- BibTeX key picker (cite/citep/citet)
- CSV-to-LaTeX table generation
- Custom `.tex` snippet picker and cursor insertion
- Headless regression test runner

## Install with LazyVim

Add this to a file such as `lua/plugins/latex-tools.lua` in your LazyVim config. It installs [latex-tools.nvim](https://github.com/ingiestein/latex-tools.nvim) from GitHub:

```lua
return {
  {
    "ingiestein/latex-tools.nvim",
    opts = {
      keymaps = { enable = true, prefix = "\\t" },
      commands = { enable = true },
      paths = {
        -- Optional overrides. Plugin-local defaults are used when omitted.
        -- template_dir = vim.fn.expand("~/.config/latex-templates"),
        -- yaml_path = vim.fn.expand("~/.config/nvim/latex-tools/courses.yaml"),
        -- tex_template_path = vim.fn.expand("~/.config/nvim/latex-tools/assignment.tex"),
        -- custom_snippets_dir = vim.fn.expand("~/.config/nvim/latex-tools/snippets"),
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

Restart Neovim and run `:Lazy sync`, then run `:LatexToolsInit` to create your starter files and snippets folder.

## Setup Options

- `keymaps.enable` (boolean): enable plugin-provided keymaps.
- `keymaps.prefix` (string): keymap prefix, defaults to `\\t`.
- `commands.enable` (boolean): enable plugin-provided user commands.
- `paths.template_dir` (string|nil): optional directory override for template assets.
- `paths.yaml_path` (string|nil): optional override for course metadata YAML.
- `paths.tex_template_path` (string|nil): optional override for assignment template path.
- `paths.custom_snippets_dir` (string|nil): optional override for the directory of user `.tex` snippets.
- `paths.python_script_path` (string|nil): optional override for renderer script path.
- `paths.test_script_path` (string|nil): optional override for test suite path.
- `python_cmd` (string|nil): optional Python executable override.

Leave the path options alone unless you want your files somewhere else.

For course metadata, the default lookup order is:

- `vim.fn.stdpath("config") .. "/latex-tools/courses.yaml"`
- bundled fallback at `templates/courses.yaml`

For the assignment template, the default lookup order is:

- `vim.fn.stdpath("config") .. "/latex-tools/assignment.tex"`
- bundled fallback at `templates/assignment.tex`

On macOS and Linux, `~/.config/nvim/latex-tools/courses.yaml` and `~/.config/nvim/latex-tools/assignment.tex` are good default locations. These are files you edit, so keeping them with your config is usually the least surprising option.

Custom snippets are read recursively from `vim.fn.stdpath("config") .. "/latex-tools/snippets"`. Put any reusable `.tex` block there; the picker displays its path relative to that directory and inserts its full contents at the cursor.

## Commands

- `:LatexToolsTest`
- `:LatexToolsInitCourses`
- `:LatexToolsInitAssignment`
- `:LatexToolsInitSnippets`
- `:LatexToolsInit`
- `:LatexToolsAssignment`
- `:LatexToolsSnippet`
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
- `require("latex-tools").init_custom_snippets_dir()`
- `require("latex-tools").init_user_files(opts)`
- `require("latex-tools").insert_assignment_template()`
- `require("latex-tools").insert_custom_snippet()`
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
- `\\tx` custom `.tex` snippet picker
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

## Getting Started

1. Run `:LatexToolsInit` to create `courses.yaml`, `assignment.tex`, and the snippets folder.
2. Edit the new `courses.yaml` with your course and profile details.
3. Add reusable `.tex` files under `~/.config/nvim/latex-tools/snippets/`. Nested folders are fine.
4. Use `:LatexToolsSnippet` or `\\tx` to choose a snippet and insert it at the cursor.

Run `:LatexToolsInit!` when you want to replace the bundled course and assignment starter files. It never removes your snippets. Python rendering uses `vim.g.python3_host_prog` when set, otherwise `python3`.

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

## Versioning

- Use semantic version tags: `vMAJOR.MINOR.PATCH`.
- Recommended initial public tag after this migration: `v0.2.0`.
