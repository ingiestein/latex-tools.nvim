# latex-tools.nvim

latex-tools.nvim is a Neovim plugin for consistently formatted LaTeX school work. It provides a document-template picker (including course-aware assignments and `subfiles` chapters), interactive helpers for figures, tables, references, citations, and reusable `.tex` snippets.

## Features

- **Document templates** — pick from bundled or user templates (`assignment.tex` and your own `.tex` files)
- **Subfile chapters** — create `subfiles` chapters from a saved course-aware parent document
- **Course-aware rendering** — fill assignment templates from `courses.yaml` via Python
- **Partial `.tex` snippets** — recursive picker for reusable blocks under `snippets/`
- **Writing helpers** — figures, tables, footnotes, references, BibTeX keys, CSV import, Markdown-like Python/R/SQL code fences
- **Project-local companions** — course-aware create copies `latex-tools-code.tex` and `latex-tools-code-minted.tex` beside the saved parent (editable per document)
- **Granular setup** — initialize metadata, templates, or snippets independently

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
        -- user_templates_dir = vim.fn.expand("~/.config/nvim/latex-tools/templates"),
        -- yaml_path = vim.fn.expand("~/.config/nvim/latex-tools/courses.yaml"),
        -- tex_template_path = vim.fn.expand("~/.config/nvim/latex-tools/templates/assignment.tex"),
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

This creates:

| Path | Purpose |
| --- | --- |
| `~/.config/nvim/latex-tools/courses.yaml` | Your profile and course catalog |
| `~/.config/nvim/latex-tools/templates/` | Document templates (`assignment.tex`, `subfile.tex`, …) |
| `~/.config/nvim/latex-tools/snippets/` | Reusable partial `.tex` blocks |

You can also initialize each part separately:

```vim
:LatexToolsInitMetadata     " courses.yaml only
:LatexToolsInitTemplates     " create missing document templates only
:LatexToolsInitSnippets      " snippets directory only
:LatexToolsInitTemplates!    " back up existing library files, then refresh from plugin
:LatexToolsInit!             " backup-refresh templates; overwrite courses.yaml; never removes snippets
```

Aliases: `:LatexToolsInitCourses` → `:LatexToolsInitMetadata`, `:LatexToolsInitAssignment` → `:LatexToolsInitTemplates`.

`:LatexToolsInitTemplates!` moves conflicting files from `latex-tools/templates/` into a timestamped sibling folder `latex-tools/templates-backup/<YYYYMMDD-HHMMSS>/`, then writes fresh bundled copies. User-only `.tex` files that are not in the plugin bundle stay in `templates/` untouched. Compare the backup folder to the new defaults and copy back any personal edits you still want.

### 3. Add your courses

Edit `courses.yaml` with your profile and courses:

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

### 4. Insert a course-aware assignment

**Save the buffer first** (e.g. `assignment.tex` in your project folder). Then run `:LatexToolsTemplate` / `\ta` and pick `assignment.tex (course-aware)`, or use `:LatexToolsAssignment`.

The plugin:

1. Prompts for course, title, and due date
2. Inserts the rendered parent document (thin shell: metadata, title, `\input{latex-tools-code}`)
3. Copies project companions beside the file when missing (`latex-tools-code.tex` and `latex-tools-code-minted.tex`) so you can edit styles for that document only

Documents never `\input` the plugin package path. Companions come from your user template library (or bundled defaults) into the project folder.

Example layout:

```text
my-assignment/
  assignment.tex
  latex-tools-code.tex
  latex-tools-code-minted.tex
  subfile/
    chapter-one.tex
```

### 5. Add a subfile chapter

From a **saved** course-aware parent document (with `% latex-tools: course-aware` near the top), run `:LatexToolsSubfile` or `\tS`:

1. The plugin creates a `subfile/` directory next to the parent file if needed
2. You are prompted for a chapter name
3. A new `.tex` file is written under `subfile/` with the parent filename substituted into the bundled subfile template
4. The new file opens in a vertical split to the right

## Templates vs snippets

| Kind | Location | Insert with | Purpose |
| --- | --- | --- | --- |
| **Document templates** | `latex-tools/templates/*.tex` | `:LatexToolsTemplate` / `\ta` | Full documents or chapter scaffolds; replaces or prepends the buffer |
| **Snippets** | `latex-tools/snippets/**/*.tex` | `:LatexToolsSnippet` / `\tx` | Partial blocks inserted at the cursor; nested folders supported |

**Add a static template** — drop a `.tex` file into your templates directory.

**Add a course-aware template** — add this near the top of the file:

```tex
% latex-tools: course-aware
```

The picker will run the course/title/due-date flow and render it with `courses.yaml` metadata. No plugin code changes are required for new static templates.

Bundled templates live in the plugin's `templates/` directory. User copies in `latex-tools/templates/` override bundled files by filename. A legacy `latex-tools/assignment.tex` path is still honored if you have not migrated yet.

`subfile.tex` and `latex-tools-code.tex` are bundled helpers excluded from the document template picker.

### Code fences

Course-aware parents `\input{latex-tools-code}` by default (the **project-local** copy). On create, both companions are copied beside the parent:

- `latex-tools-code.tex` — portable `tcolorbox` + `listings` (default; no shell-escape)
- `latex-tools-code-minted.tex` — `tcolorbox` + `minted` + Pygments (opt-in)

**API** (same in both backends):

```tex
\begin{mdcode}{Python}
print("hello")
\end{mdcode}

\begin{python}
import pandas as pd
\end{python}

\begin{rcode}
summary(df)
\end{rcode}

\begin{sql}
SELECT 1;
\end{sql}
```

Use `\begin{mdcode}{Lang}` for any listings/Pygments language; `\tp` / `\tr` / `\ts` insert the short wrappers.

**Opt in to minted** (needs `pygmentize` on PATH and `-shell-escape`):

```vim
:LatexToolsUseMinted
```

Restore listings with `:LatexToolsUseMinted!`. Or edit the parent `\input{...}` line by hand.

Example `latexmkrc` snippet for minted:

```perl
$pdflatex = 'xelatex -shell-escape %O %S';
$xelatex  = 'xelatex -shell-escape %O %S';
```

Edit the project-local companion to restyle fences for that paper only. Re-run `:LatexToolsInitTemplates!` to refresh the **user library** (with backup); that does not change companions already copied into an existing project.

## Everyday Tools

| Keymap | Action |
| --- | --- |
| `\ta` | Document template picker |
| `\tS` | Create subfile chapter from saved course-aware document |
| `\tx` | Custom `.tex` snippet picker |
| `\tf` | Figure with image picker and caption |
| `\tF` | Placeholder figure |
| `\tb` | Interactive table builder |
| `\tB` | Placeholder table |
| `\tn` | Footnote prompt |
| `\tR` | Reference to a buffer label |
| `\tk` | BibTeX citation key |
| `\tv` | Table from CSV |
| `\tp` / `\tr` / `\ts` | Python / R / SQL Markdown-like code fences |
| `\tT` | Run tests |

## Configuration

The default setup is enough for most users.

```lua
opts = {
  keymaps = { enable = true, prefix = "\\t" },
  commands = { enable = true },
  paths = {
    -- user_templates_dir = vim.fn.expand("~/.config/nvim/latex-tools/templates"),
    -- yaml_path = vim.fn.expand("~/.config/nvim/latex-tools/courses.yaml"),
    -- tex_template_path = vim.fn.expand("~/.config/nvim/latex-tools/templates/assignment.tex"),
    -- custom_snippets_dir = vim.fn.expand("~/.config/nvim/latex-tools/snippets"),
  },
  -- python_cmd = vim.g.python3_host_prog,
}
```

| Option | Description |
| --- | --- |
| `keymaps.enable` | Enable plugin keymaps (default: `true`) |
| `keymaps.prefix` | Keymap prefix (default: `\\t`) |
| `commands.enable` | Enable `:LatexTools*` commands (default: `true`) |
| `paths.template_dir` | Override bundled template assets directory |
| `paths.user_templates_dir` | Override user document template directory |
| `paths.yaml_path` | Override course metadata file |
| `paths.tex_template_path` | Override assignment template used for rendering |
| `paths.custom_snippets_dir` | Override reusable snippet directory |
| `paths.python_script_path` | Override renderer script |
| `paths.test_script_path` | Override test suite path |
| `python_cmd` | Override Python executable |

### Security note

Overrides such as `paths.python_script_path` and `python_cmd` cause the plugin to execute programs with your user privileges. Only use trusted interpreters and scripts. The plugin warns when `python_script_path` is overridden at setup. Command failures are sanitized before display, but treat renderer output as untrusted text.

## Commands

### Initialization

| Command | Description |
| --- | --- |
| `:LatexToolsInit[!]` | Initialize metadata, templates, and snippets |
| `:LatexToolsInitMetadata[!]` | Create `courses.yaml` from bundled example |
| `:LatexToolsInitTemplates[!]` | Create missing templates; bang backs up then refreshes from plugin |
| `:LatexToolsInitSnippets` | Create the snippets directory |
| `:LatexToolsInitCourses[!]` | Alias for `:LatexToolsInitMetadata[!]` |
| `:LatexToolsInitAssignment[!]` | Alias for `:LatexToolsInitTemplates[!]` |

### Templates and snippets

| Command | Description |
| --- | --- |
| `:LatexToolsTemplate` | Choose and insert a document template |
| `:LatexToolsAssignment` | Insert a rendered assignment (skips template picker) |
| `:LatexToolsSubfile` | Create a subfile chapter from the current course-aware document |
| `:LatexToolsUseMinted[!]` | Switch parent to minted fences (`!` restores listings) |
| `:LatexToolsSnippet` | Choose and insert a custom `.tex` snippet |

### Writing helpers

| Command | Description |
| --- | --- |
| `:LatexToolsFigure` | Insert figure with image picker |
| `:LatexToolsFigurePlaceholder` | Insert placeholder figure |
| `:LatexToolsTable` | Build a table through prompts |
| `:LatexToolsTablePlaceholder` | Insert placeholder table |
| `:LatexToolsFootnote` | Prompt for and insert a footnote |
| `:LatexToolsReference` | Insert a reference to a label |
| `:LatexToolsBib` | Insert a BibTeX citation |
| `:LatexToolsCSVTable` | Convert a CSV file to a LaTeX table |

### Testing

| Command | Description |
| --- | --- |
| `:LatexToolsTest` | Run the headless regression suite |

## Public Lua API

### Setup and config

- `require("latex-tools").setup(opts)`
- `require("latex-tools").get_config()`

### Initialization

- `require("latex-tools").init_metadata(opts)` — `courses.yaml`
- `require("latex-tools").init_templates(opts)` — document templates
- `require("latex-tools").init_snippets()` — snippets directory
- `require("latex-tools").init_all(opts)` — any combination; `opts` may include `metadata`, `templates`, `snippets`, `force`

```lua
-- Re-init templates only, overwriting existing files
require("latex-tools").init_all({ templates = true, metadata = false, snippets = false, force = true })
```

Backward-compatible aliases: `init_course_metadata`, `init_user_templates`, `init_assignment_template`, `init_custom_snippets_dir`, `init_user_files`.

### Insertion

- `require("latex-tools").insert_template()`
- `require("latex-tools").create_subfile()`
- `require("latex-tools").use_minted_companion({ minted = true|false })`
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
- `require("latex-tools").insert_snippet(key)` — `p`, `r`, or `s`

### Testing

- `require("latex-tools").run_tests()`

## Testing

```bash
nvim --headless -u NONE -l tests/templates_spec.lua
```

In Neovim: `:LatexToolsTest` or `\tT`.

## Changelog

See `CHANGELOG.md` for release history. Recent unreleased work includes the unified template picker, `subfile.tex`, granular init commands, template metadata comments, due-date validation, and init/error-handling improvements.
