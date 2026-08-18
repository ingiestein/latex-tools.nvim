# latex-tools.nvim

latex-tools.nvim is a small Neovim plugin for consistently formatted LaTeX assignments. It helps with course-aware assignment files, figures, tables, references, citations, and reusable snippets. If you enjoy Neovim, LaTeX, and unnecessarily polished school papers, this is for you.

## Getting Started

### 1. Install with LazyVim

Add this to `lua/plugins/latex-tools.lua` in your LazyVim config:

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

Restart Neovim, then run `:Lazy sync` to install the plugin.

### 2. Create your starter files

Run:

```vim
:LatexToolsInit
```

This creates these user-owned files and folders:

- `~/.config/nvim/latex-tools/courses.yaml`
- `~/.config/nvim/latex-tools/assignment.tex`
- `~/.config/nvim/latex-tools/snippets/`

### 3. Add your courses

Edit `courses.yaml` with your profile and courses. You can add as many entries under `course_catalog` as you need.

```yaml
academic_profile:
  institution: Example University
  degree_program: Example Graduate Program
  student_name: Jane Student
  student_id: "00000000"
  default_term: Autumn
  default_year: 2026

course_catalog:
  - key: course_applied_methods
    course_code: COURSE 6101-001
    class_number: "10001"
    course_title: Applied Research Methods
    course_type: Lecture
    meeting_time: MoWe 10:00AM - 11:30AM
    location: Building A 101
    instructors:
      - A. Instructor
    credits: 3.00

selection:
  active_course_key: course_applied_methods
  active_assignment_title: Assignment Title
  active_due_date: 2026-08-15
```

### 4. Create an assignment

Open a new buffer, then run `:LatexToolsAssignment` or use `\ta`. Choose a course, enter an assignment title and due date, and the plugin inserts the rendered assignment document.

## Everyday Tools

- `\tf`: choose an image and insert a figure with a caption.
- `\tb`: build a table by answering a few prompts.
- `\tR`: insert a `\ref`, `\pageref`, or `\autoref` for a label in the current buffer.
- `\tk`: choose a BibTeX key and insert a citation.
- `\tv`: turn a CSV file into a LaTeX table.
- `\tx`: choose one of your reusable `.tex` snippets and insert it at the cursor.
- `\tp`, `\tr`, and `\ts`: insert the built-in Python, R, and SQL listing blocks.

## Custom Files

### Course metadata and assignment template

The plugin first looks for `courses.yaml` and `assignment.tex` in `vim.fn.stdpath("config") .. "/latex-tools"`. If either file does not exist, it falls back to the bundled sample in `templates/`.

`assignment.tex` is the single course-aware assignment template in the current release. You can edit your local copy freely; additional user-defined full-document templates are planned for a future release.

Run `:LatexToolsInit!` to replace your local course metadata and assignment template with fresh bundled copies. It never removes snippets.

### Reusable snippets

Put reusable `.tex` blocks anywhere under `vim.fn.stdpath("config") .. "/latex-tools/snippets"`. Nested folders are supported, and the picker shows each file path relative to the snippets folder.

Use `:LatexToolsSnippet` or `\tx` to insert the selected file at the cursor.

## Configuration

The default setup is enough for most users. Add options only when you want to change the keymap prefix, disable commands or mappings, move user files, or select a Python interpreter.

```lua
opts = {
  keymaps = { enable = true, prefix = "\\t" },
  commands = { enable = true },
  paths = {
    -- yaml_path = vim.fn.expand("~/.config/nvim/latex-tools/courses.yaml"),
    -- tex_template_path = vim.fn.expand("~/.config/nvim/latex-tools/assignment.tex"),
    -- custom_snippets_dir = vim.fn.expand("~/.config/nvim/latex-tools/snippets"),
  },
  -- python_cmd = vim.g.python3_host_prog,
}
```

Available options:

- `keymaps.enable` (boolean): enable plugin-provided keymaps.
- `keymaps.prefix` (string): keymap prefix, defaults to `\\t`.
- `commands.enable` (boolean): enable plugin-provided user commands.
- `paths.template_dir` (string|nil): optional directory override for bundled template assets.
- `paths.yaml_path` (string|nil): optional course metadata override.
- `paths.tex_template_path` (string|nil): optional assignment template override.
- `paths.custom_snippets_dir` (string|nil): optional reusable snippet directory override.
- `paths.python_script_path` (string|nil): optional renderer script override.
- `paths.test_script_path` (string|nil): optional test suite override.
- `python_cmd` (string|nil): optional Python executable override.

## Commands

- `:LatexToolsTest`: run the plugin's headless regression suite.
- `:LatexToolsInitCourses[!]`: create the user `courses.yaml` from the bundled example; use `!` to overwrite it.
- `:LatexToolsInitAssignment[!]`: create the user `assignment.tex` from the bundled template; use `!` to overwrite it.
- `:LatexToolsInitSnippets`: create the custom snippets directory.
- `:LatexToolsInit[!]`: initialize course metadata, the assignment template, and the snippets directory; use `!` to overwrite the course and assignment files.
- `:LatexToolsAssignment`: choose a course and insert a rendered assignment document.
- `:LatexToolsSnippet`: choose and insert a custom `.tex` snippet at the cursor.
- `:LatexToolsFigure`: choose an image and add a captioned figure.
- `:LatexToolsFigurePlaceholder`: insert a figure placeholder.
- `:LatexToolsTable`: create a table through prompts.
- `:LatexToolsTablePlaceholder`: insert a table placeholder.
- `:LatexToolsFootnote`: prompt for and insert a footnote.
- `:LatexToolsReference`: choose a label and insert a reference.
- `:LatexToolsBib`: choose a BibTeX key and insert a citation.
- `:LatexToolsCSVTable`: choose a CSV file and convert it to a LaTeX table.

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

Prefix defaults to `\t`.

- `\ta`: assignment template picker
- `\tx`: custom `.tex` snippet picker
- `\tf`: figure picker
- `\tF`: placeholder figure
- `\tb`: interactive table
- `\tB`: placeholder table
- `\tn`: footnote prompt
- `\tR`: label reference
- `\tk`: BibTeX citation key
- `\tv`: table from CSV
- `\tp`: Python snippet
- `\tr`: R snippet
- `\ts`: SQL snippet
- `\tT`: run tests

## Testing

- Canonical plugin-local test run:

```bash
nvim --headless -u NONE -l tests/templates_spec.lua
```

- In your existing Neovim setup, use:
  - `:LatexToolsTest`
  - `\tT`

## Changelog

- See `CHANGELOG.md` for migration and release milestones.

## Versioning

- Use semantic version tags: `vMAJOR.MINOR.PATCH`.
- Recommended initial public tag after this migration: `v0.2.1`.
