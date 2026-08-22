# Multifile Document Support

This document proposes a multifile framework for `latex-tools.nvim` that keeps the current single-file assignment workflow intact while adding a project-oriented mode for LaTeX documents made of multiple files.

## Goals

- Keep the existing assignment template flow working as-is.
- Add first-class support for document trees made of a root file plus included child files.
- Make it easy to create, browse, insert, and render multi-file LaTeX projects.
- Reuse the plugin's current patterns: path resolution, pickers, insertion helpers, and Python-based rendering.

## Core Idea

The plugin should support two document modes:

- Single-file mode: the current assignment template inserted into the active buffer.
- Project mode: a LaTeX document represented by a manifest plus a file tree.

The manifest becomes the source of truth for project metadata, layout, and build targets.

For the hierarchy itself, the best first implementation is probably not a SQLite database. A database is good if you want rich querying and very large projects, but it adds a second persistence layer, migration work, and more failure modes. For a Neovim plugin aimed at LaTeX authoring, a YAML-backed tree with stable node identifiers is the better default because it stays human-readable, portable, and easy to diff. If the hierarchy grows more complex later, a SQLite cache can be added as an implementation detail, not as the source of truth.

Recommended hierarchy model:

- YAML is the authoritative document tree.
- Each node has a stable `id`, a `parent_id`, and an `order` field.
- The tree is effectively an adjacency list with sibling ordering.
- The generated `input.tex` is a derived file that reflects the current hierarchy.

This gives you the same practical benefits as SQL-managed trees while keeping the file format editable.

## Proposed File Layout

```text
my-paper/
  latex-tools.project.yaml
  main.tex
  chapters/
    introduction.tex
    methods.tex
    results.tex
  appendices/
    appendix-a.tex
  figures/
  tables/
  bib/
```

Suggested conventions:

- `main.tex` is the root file and contains `\input{...}` or `\include{...}` statements.
- Child files store section-level content only.
- Shared assets live in predictable folders next to the manifest.
- The manifest path can be overridden, but the project root should be discoverable from the manifest location.
- The tree editor should work from a scratch or temporary YAML buffer and only commit changes on an explicit save command.

## Tree Pane UX

The primary interaction should be a side pane that shows the current hierarchy as a nested list.

Desired behavior:

- Open a dedicated Neovim side pane for the project tree.
- Expand and collapse nodes.
- Move nodes up, down, in, and out.
- Reparent a node by changing its `parent_id`.
- Reorder siblings by changing `order`.
- Create, rename, and delete files from the tree view.
- Jump from a tree node to the corresponding `.tex` file.

The pane should behave like a project navigator, not just a file picker.

Recommended implementation options:

- Start with a floating or sidebar tree buffer rendered from YAML.
- Use a lightweight tree model in Lua, backed by a hidden scratch buffer for edits.
- Keep keyboard mappings focused on structural operations: move up/down, indent/outdent, add sibling, add child, delete node, open file, save tree.

### Sidebar interaction rules

- The sidebar renders the document hierarchy as a real tree, not a flat file list.
- Standard Neovim window navigation is preserved. Panel movement uses normal window commands such as Ctrl-w h, Ctrl-w j, Ctrl-w k, and Ctrl-w l.
- The plugin must not remap global window motion keys.
- Tree mappings are buffer-local and active only when the sidebar buffer has focus.
- Cursor motion in the tree remains normal j and k for selection.

### Sidebar keybindings for structure edits

Recommended default tree-buffer mappings:

- J: move selected node down within the same parent.
- K: move selected node up within the same parent.
- >: move selected node in, making it a child of the previous sibling.
- <: move selected node out, making it a sibling of its current parent.
- Enter: open selected node file in the main editing window.
- za: toggle expand and collapse for the selected node.
- s: save draft tree.
- S: commit draft to canonical YAML and regenerate derived files.

These mappings match common Vim mental models:

- J and K are directional reorder actions.
- > and < represent structural indentation and outdentation.

### Operation outcome guarantees

When using J or K:

- Only sibling order changes.
- Parent relationship stays the same.

When using >:

- Node becomes the last child of the previous sibling.
- Node stays in the same file unless path rename is explicitly requested.

When using <:

- Node becomes a sibling of its current parent.
- Node is placed immediately after the former parent in sibling order.

## Tree Mutation Contract

The sidebar should be the editor for structural changes, but only the YAML manifest is canonical. The tree view mutates an in-memory model first, then writes a draft YAML buffer, then commits to disk on an explicit save action.

The tree editor should only mutate these persisted fields:

- `tree[*].parent_id`
- `tree[*].order`
- `tree[*].title`
- `tree[*].path`
- `tree[*].kind`
- `tree[*].include`
- `tree[*].heading_level`
- `tree[*].label`

The editor should not directly store visual state such as expanded/collapsed nodes, cursor position, or filter text in the project YAML.

### Core node operations

#### `move_up`

- Moves the selected node above its previous sibling.
- Mutates only sibling `order` values.
- Does not change `parent_id`.
- If the node is already first among siblings, the operation is a no-op.

#### `move_down`

- Moves the selected node below its next sibling.
- Mutates only sibling `order` values.
- Does not change `parent_id`.
- If the node is already last among siblings, the operation is a no-op.

#### `indent` or `move_in`

- Reparents the selected node under the previous sibling.
- Changes `parent_id` to the previous sibling's `id`.
- Updates the node's `order` to become the last child under the new parent.
- Leaves the node's `path` unchanged unless a user command explicitly renames or relocates the file.
- If there is no previous sibling, the operation is a no-op.

#### `outdent` or `move_out`

- Reparents the selected node to the parent of its current parent.
- Sets `parent_id` to the grandparent `id`, or to `null` if the node becomes top-level.
- Places the node after its former parent among the new sibling set.
- Leaves the node's `path` unchanged unless explicitly renamed.

#### `add_sibling`

- Creates a new node at the same hierarchy level as the selected node.
- Sets the new node's `parent_id` to the selected node's `parent_id`.
- Assigns a fresh `id`.
- Inserts the node after the selected node and renumbers sibling `order` values as needed.
- Creates a new `.tex` file if `defaults.create_missing_files` is true.

#### `add_child`

- Creates a new node nested under the selected node.
- Sets the new node's `parent_id` to the selected node's `id`.
- Assigns a fresh `id`.
- Places the node at the end of the child list.
- Creates a new `.tex` file if `defaults.create_missing_files` is true.

#### `rename_node`

- Updates `title` for the selected node.
- Optionally updates `label` if the user requests synchronized labels.
- Does not change `id`.
- Does not change file location unless a separate rename-file command is used.

#### `rename_file`

- Updates `path` for the selected node.
- Renames or moves the backing file on disk when safe to do so.
- Leaves `id`, `parent_id`, and `order` unchanged.
- If the file already exists at the destination, the command should prompt before overwriting.

#### `delete_node`

- Removes the selected node from the tree.
- Also removes its descendants unless the user explicitly chooses to promote children.
- Deletes the backing file only when the user confirms destructive file removal.
- Renumbers sibling `order` values after removal.

#### `promote_children`

- Reattaches a deleted or moved node's children to its parent.
- Preserves the children in the tree while removing the selected node itself.
- Useful when a file should disappear but its subsections should remain.

#### `toggle_include`

- Cycles or sets the node's `include` mode.
- Changes whether the node appears in generated `input.tex`.
- Does not change structure, only rendering behavior.

### Derived sidebar state

The sidebar may track non-persisted state such as:

- expanded/collapsed nodes
- selected node
- search filter
- dirty draft status
- pending file create/rename confirmations

None of these belong in the YAML manifest.

### Draft write rules

When the sidebar mutates the tree:

1. Update the in-memory tree model.
2. Mark the draft as dirty.
3. Serialize the current model to the draft YAML buffer.
4. Save the draft buffer to the draft file on explicit command or autosave policy.
5. Commit the draft to the canonical manifest only when the user confirms save.

This keeps the visual editor responsive while still making the manifest the only durable source of truth.

## Event Model

The sidebar should follow a deterministic event pipeline so every key action has predictable side effects.

### Runtime state

Maintain this in-memory state while the sidebar is open:

- project_root
- manifest_path
- draft_path
- tree_model
- selected_node_id
- expanded_node_ids
- dirty
- last_autosave_at
- pending_fs_ops
- last_error

Where:

- tree_model is the authoritative in-memory model during an editing session.
- dirty means tree_model differs from the last committed manifest.
- pending_fs_ops tracks file create, move, and delete work not yet committed.

### Event classes

- Navigation events: selection changes, expand or collapse, open node.
- Mutation events: move up, move down, move in, move out, add, rename, delete, toggle include.
- Persistence events: save draft, autosave draft, commit draft, restore draft.
- System events: buffer leave, focus lost, editor exit, file system conflict.

### Keypress to transition rules

For mutation keypresses such as J, K, greater-than, and less-than:

1. Validate preconditions on selected node and target parent or sibling.
2. Apply the mutation to tree_model.
3. Recompute sibling order for affected parent sets.
4. Mark dirty true.
5. Queue any related file operations in pending_fs_ops.
6. Re-render sidebar buffer from tree_model.
7. Trigger autosave policy check.

For non-mutation keypresses such as Enter and za:

- Do not mutate persisted schema fields.
- Do not set dirty unless an operation changes tree_model.

### Autosave policy

Autosave writes only the draft file, never the canonical manifest.

Recommended triggers:

- after N mutation events
- after T seconds since last autosave when dirty is true
- on sidebar buffer leave when dirty is true
- on focus lost when dirty is true

Autosave algorithm:

1. Serialize tree_model plus project metadata to draft YAML text.
2. Write to draft_path atomically using temp file then rename.
3. Update last_autosave_at.
4. Keep dirty true.
5. Show lightweight status message.

### Commit pipeline

Commit is explicit and should be bound to the save command in the sidebar.

Commit algorithm:

1. Validate schema and invariants against tree_model.
2. Check pending_fs_ops for conflicts such as destination path already exists.
3. Create backup of canonical manifest in draft.backup_dir with timestamp.
4. Apply pending_fs_ops in safe order:
  - create directories
  - create new files
  - move or rename files
  - delete files only after explicit confirmation
5. Write canonical manifest atomically.
6. Regenerate input.tex from committed tree order and include mode.
7. Clear pending_fs_ops.
8. Set dirty false.
9. Emit success notification.

### Failure and rollback behavior

If commit fails at any stage:

- Keep the in-memory tree_model unchanged.
- Keep dirty true.
- Preserve the draft file.
- Restore canonical manifest from backup if it was modified.
- Report precise error with failed operation and path.
- Keep the sidebar open so the user can fix and retry.

File operation rollback strategy:

- Track each applied file operation.
- For reversible operations like rename, store inverse operation.
- For deletes, move to a temporary trash path first, then purge only on successful commit.

### Exit and recovery semantics

On editor exit with dirty true:

- Force an autosave draft write attempt.
- If write succeeds, store a recovery marker.
- On next project open, prompt to restore draft or discard.

Recovery marker minimal fields:

- manifest_path
- draft_path
- saved_at
- schema_version

### Event ordering guarantees

- Only one mutation event should execute at a time.
- Sidebar re-render must reflect the exact post-mutation tree_model.
- Commit and autosave should be mutually exclusive critical sections.
- No background event may write the canonical manifest without explicit user commit.

These guarantees keep behavior understandable and prevent hidden writes.

## Keymap and Command Spec

This section defines a single implementation contract for tree-buffer key actions and project commands.

### Sidebar keymap table

| Key | Action | Preconditions | Schema fields touched | Status message | Error codes |
| --- | --- | --- | --- | --- | --- |
| `J` | Move node down | Selected node has a next sibling | `tree[*].order` | `Moved node down` | `E_NO_SELECTION`, `E_NO_NEXT_SIBLING`, `E_INVALID_TREE` |
| `K` | Move node up | Selected node has a previous sibling | `tree[*].order` | `Moved node up` | `E_NO_SELECTION`, `E_NO_PREV_SIBLING`, `E_INVALID_TREE` |
| `>` | Move node in | Selected node has a previous sibling that can become parent | `tree[*].parent_id`, `tree[*].order` | `Indented node` | `E_NO_SELECTION`, `E_NO_PREV_SIBLING`, `E_CYCLE_DETECTED`, `E_INVALID_TREE` |
| `<` | Move node out | Selected node has a parent | `tree[*].parent_id`, `tree[*].order` | `Outdented node` | `E_NO_SELECTION`, `E_ALREADY_ROOT`, `E_INVALID_TREE` |
| `a` | Add sibling | Selected node exists | `tree[*].id`, `tree[*].parent_id`, `tree[*].order`, `tree[*].title`, `tree[*].path` | `Added sibling node` | `E_NO_SELECTION`, `E_ID_COLLISION`, `E_PATH_CONFLICT`, `E_INVALID_TREE` |
| `A` | Add child | Selected node exists | `tree[*].id`, `tree[*].parent_id`, `tree[*].order`, `tree[*].title`, `tree[*].path` | `Added child node` | `E_NO_SELECTION`, `E_ID_COLLISION`, `E_PATH_CONFLICT`, `E_INVALID_TREE` |
| `r` | Rename node title | Selected node exists | `tree[*].title` | `Renamed node` | `E_NO_SELECTION`, `E_EMPTY_TITLE`, `E_INVALID_TREE` |
| `R` | Rename or move node file | Selected node exists, destination is valid | `tree[*].path` | `Updated node path` | `E_NO_SELECTION`, `E_PATH_CONFLICT`, `E_FS_RENAME_FAILED`, `E_INVALID_TREE` |
| `x` | Delete node | Selected node exists | `tree[*].parent_id`, `tree[*].order` and node removal | `Deleted node` | `E_NO_SELECTION`, `E_DELETE_CANCELLED`, `E_FS_DELETE_FAILED`, `E_INVALID_TREE` |
| `p` | Promote children | Selected node exists and has children | `tree[*].parent_id`, `tree[*].order` | `Promoted children` | `E_NO_SELECTION`, `E_NO_CHILDREN`, `E_INVALID_TREE` |
| `i` | Toggle include mode | Selected node exists | `tree[*].include` | `Updated include mode` | `E_NO_SELECTION`, `E_INVALID_INCLUDE_MODE` |
| `Enter` | Open node file | Selected node has path | None | `Opened file` | `E_NO_SELECTION`, `E_FILE_NOT_FOUND`, `E_OPEN_FAILED` |
| `za` | Toggle expand or collapse | Selected node exists | None | `Toggled node` | `E_NO_SELECTION` |
| `s` | Save draft | Draft path is writable | None in canonical manifest, draft write only | `Draft saved` | `E_DRAFT_WRITE_FAILED`, `E_SERIALIZE_FAILED` |
| `S` | Commit draft | Draft is valid, commit lock available | Canonical manifest write and derived file regeneration | `Project committed` | `E_VALIDATION_FAILED`, `E_BACKUP_FAILED`, `E_COMMIT_FAILED`, `E_RENDER_FAILED` |
| `u` | Restore draft | Draft exists | Replaces in-memory model from draft | `Draft restored` | `E_DRAFT_NOT_FOUND`, `E_DRAFT_PARSE_FAILED` |

Notes:

- Panel movement remains native via Ctrl-w window motions and is not part of this table.
- Tree keymaps are buffer-local to the sidebar only.

### Command specification table

| Command | Purpose | Preconditions | State transitions | Primary side effects | Error codes |
| --- | --- | --- | --- | --- | --- |
| `:LatexToolsProjectTree` | Open sidebar tree editor | Project manifest exists or can be initialized | `closed -> open` | Loads manifest into tree model and draft context | `E_MANIFEST_NOT_FOUND`, `E_MANIFEST_PARSE_FAILED` |
| `:LatexToolsProjectSaveTree` | Save current draft | Sidebar session is open | `dirty stays true` unless commit follows | Writes draft YAML atomically | `E_NO_ACTIVE_SESSION`, `E_DRAFT_WRITE_FAILED` |
| `:LatexToolsProjectCommitTree` | Commit draft to canonical manifest | Sidebar session open and validation passes | `dirty true -> false` on success | Backup, fs ops, manifest write, input regeneration | `E_NO_ACTIVE_SESSION`, `E_VALIDATION_FAILED`, `E_COMMIT_FAILED`, `E_RENDER_FAILED` |
| `:LatexToolsProjectRestoreTree` | Restore latest draft | Draft file exists | `model replaced`, `dirty true` | Rehydrates in-memory tree from draft | `E_DRAFT_NOT_FOUND`, `E_DRAFT_PARSE_FAILED` |
| `:LatexToolsProjectRender` | Regenerate derived files only | Canonical manifest valid | no tree mutation | Rewrites generated files such as input.tex | `E_MANIFEST_PARSE_FAILED`, `E_RENDER_FAILED` |
| `:LatexToolsProjectValidate` | Validate schema and invariants | Manifest or draft is readable | no mutation | Produces diagnostics report | `E_MANIFEST_PARSE_FAILED`, `E_VALIDATION_FAILED` |

### Error code catalog

| Code | Meaning | Typical remediation |
| --- | --- | --- |
| `E_NO_SELECTION` | No node is selected in sidebar | Move cursor to a node and retry |
| `E_NO_PREV_SIBLING` | Operation requires previous sibling | Select a node that is not first sibling |
| `E_NO_NEXT_SIBLING` | Operation requires next sibling | Select a node that is not last sibling |
| `E_ALREADY_ROOT` | Cannot outdent a top-level node | Choose a non-root node |
| `E_CYCLE_DETECTED` | Mutation would create ancestor cycle | Choose a different target parent |
| `E_ID_COLLISION` | Generated node id already exists | Retry with a different title or id |
| `E_PATH_CONFLICT` | File path is already used | Provide a unique path |
| `E_FILE_NOT_FOUND` | Node path does not exist on disk | Create file or fix path |
| `E_DRAFT_NOT_FOUND` | No recoverable draft exists | Start a new session or check draft path |
| `E_VALIDATION_FAILED` | Schema or invariants failed | Fix diagnostics and retry commit |
| `E_COMMIT_FAILED` | Commit pipeline failed | Inspect detailed error, restore backup if needed |
| `E_RENDER_FAILED` | input regeneration failed | Fix manifest or renderer error and rerun |

### Recommended function names for implementation

Tree mutation handlers:

- `project.tree.move_up(node_id)`
- `project.tree.move_down(node_id)`
- `project.tree.move_in(node_id)`
- `project.tree.move_out(node_id)`
- `project.tree.add_sibling(node_id, payload)`
- `project.tree.add_child(node_id, payload)`
- `project.tree.rename_node(node_id, new_title)`
- `project.tree.rename_file(node_id, new_path)`
- `project.tree.delete_node(node_id, opts)`
- `project.tree.promote_children(node_id)`
- `project.tree.toggle_include(node_id)`

Persistence handlers:

- `project.draft.save()`
- `project.draft.restore()`
- `project.commit.run()`
- `project.render.input_file()`
- `project.validate.schema()`

## Main File Strategy

Keep `main.tex` as the preamble and project entry point.

The main body should contain a single generated include point such as:

```tex
\begin{document}
\input{input.tex}
\end{document}
```

or, if you want to keep the file even more explicit:

```tex
\begin{document}
% latex-tools: begin generated body
\input{input.tex}
% latex-tools: end generated body
\end{document}
```

The important rule is that the software only rewrites the generated include region, not the whole `main.tex` file.

`input.tex` then becomes the derived document body assembled from the YAML hierarchy. That keeps the human-edited preamble stable while allowing the body tree to be regenerated safely.

## YAML Data Model

The manifest should be versioned and explicit. The first useful shape is a single YAML file that contains both project metadata and the document tree.

Recommended versioned schema name: `latex_tools_project_v1`.

Design goals:

- Human-readable and easy to diff.
- Stable node identities for reorder operations.
- Minimal ambiguity about what is source data versus derived data.
- Straightforward validation before regeneration.

The manifest should define two concepts:

- project metadata: where the document lives and how it builds.
- hierarchy nodes: the ordered tree of sections, subsections, and file-backed units.

Example:

```yaml
schema_version: 1

project:
  name: Example Report
  root_file: main.tex
  body_file: input.tex
  manifest_file: latex-tools.project.yaml
  output_dir: build
  root_dir: .
  generated_region_tag: latex-tools

draft:
  enabled: true
  path: .latex-tools/draft.yaml
  autosave: true
  backup_dir: .latex-tools/backups

tree:
  - id: intro
    parent_id: null
    order: 10
    title: Introduction
    path: chapters/introduction.tex
    kind: section
    include: input
  - id: methods
    parent_id: null
    order: 20
    title: Methods
    path: chapters/methods.tex
    kind: section
    include: input
  - id: experiments
    parent_id: methods
    order: 10
    title: Experiments
    path: chapters/methods/experiments.tex
    kind: subsection
    include: input

defaults:
  heading_level: section
  file_extension: .tex
  create_missing_files: true
  open_strategy: split

build:
  engine: pdflatex
  passes: 2
  bibliography_tool: biber
  watch: false
```

Why this shape works:

- `id` gives each node a stable identity even if the title or path changes.
- `parent_id` supports nesting.
- `order` supports sibling reordering without renumbering everything.
- The structure is easy to render into a tree pane and easy to serialize back to YAML.
- `schema_version` gives room for future migrations.
- `draft` isolates the temporary edit/restore workflow from the canonical manifest.
- `include` lets the renderer know whether a node should appear in `input.tex`, be treated as a standalone file, or both.

If you want even smoother reordering, the `order` field can use sparse numbers like `10`, `20`, `30`, so moving a node usually only changes one value.

## Schema Rules

The schema should be strict enough to validate before render time.

Required top-level keys:

- `schema_version` - integer, currently `1`.
- `project` - mapping with project metadata.
- `tree` - list of node records.

Recommended top-level keys:

- `draft` - draft buffer and backup settings.
- `defaults` - default file and heading behavior.
- `build` - optional build settings.

`project` fields:

- `name` - string, required.
- `root_file` - string, required.
- `body_file` - string, required.
- `manifest_file` - string, optional but recommended.
- `output_dir` - string, optional.
- `root_dir` - string, optional, defaults to manifest directory.
- `generated_region_tag` - string, optional, defaults to `latex-tools`.

`draft` fields:

- `enabled` - boolean.
- `path` - string.
- `autosave` - boolean.
- `backup_dir` - string.

`defaults` fields:

- `heading_level` - string such as `section` or `subsection`.
- `file_extension` - string, usually `.tex`.
- `create_missing_files` - boolean.
- `open_strategy` - string such as `split`, `edit`, or `vsplit`.

`tree` node fields:

- `id` - string, required, unique across the tree.
- `parent_id` - string or null.
- `order` - integer, required.
- `title` - string, required.
- `path` - string, required.
- `kind` - string, optional, such as `section`, `subsection`, `file`, or `appendix`.
- `include` - string, optional, such as `input`, `include`, `none`, or `generated`.
- `heading_level` - string, optional override for this node.
- `label` - string, optional explicit LaTeX label.
- `children` - not stored directly in YAML; the tree is reconstructed from `parent_id`.

Validation invariants:

- Node IDs must be unique.
- Every non-null `parent_id` must reference an existing node.
- Siblings under the same parent should have unique `order` values.
- `root_file` and `body_file` must be relative to the project root or manifest directory.
- The derived tree must not contain cycles.
- The generated `input.tex` file should not be hand-edited outside the generated region.

If the plugin later wants a more formal schema, this YAML can be validated against a JSON Schema or a Lua-side validator without changing the on-disk format.

## Ordering Model

For tree editing, the most practical SQL-style model is not nested sets. Nested sets are elegant for reads but painful for reordering because moving one node changes many rows.

The better options here are:

- Adjacency list plus `order`: easiest to edit and serialize, best fit for YAML.
- Closure table: good if you later want rich ancestor/descendant queries across large projects.

My recommendation is:

- Use adjacency list plus `order` as the user-facing source of truth.
- Optionally derive a closure-table-like cache in memory if you need fast tree queries.
- Only add SQLite if the project reaches a scale where YAML parsing and tree reconstruction become a real bottleneck.

That keeps the editing model simple and the implementation maintainable.

## Editing and Recovery

Because you want a temporary editable YAML view, the workflow should be split into draft and commit stages.

Proposed flow:

1. Open the project tree editor.
2. Load the YAML into a scratch buffer or draft buffer.
3. Let the user reorder and edit nodes.
4. Save the buffer to a draft file automatically or manually.
5. Commit the draft to the real YAML file with an explicit command.
6. Regenerate `input.tex` only after a successful commit.

Recovery options:

- Keep a timestamped backup copy of the last committed YAML.
- Store a shadow draft under the plugin config directory.
- Use Neovim swap/undo when possible, but do not rely on them alone.
- Offer a restore command that reopens the last draft after an unexpected exit.

If you want stronger crash safety, the plugin can autosave the draft on cursor hold or when the tree buffer loses focus, while still requiring an explicit commit to update the canonical YAML.

## Regeneration Model

The key idea is that the software should regenerate only derived files.

Suggested derived files:

- `input.tex` for the document body.
- optional node-level stubs for new sections or subsections.
- optional build metadata caches.

Suggested source-of-truth files:

- the YAML hierarchy.
- `main.tex` for preamble and project bootstrap.

This division avoids rewriting the whole project and makes accidental data loss less likely.

## Canonical Schema Note

The schema in the `YAML Data Model` section above is the authoritative v1 format. Any later examples or implementation notes should follow that shape rather than introducing a second file layout.

## Command Surface

Add project-aware commands alongside the existing single-file commands:

- `:LatexToolsProjectInit` - create a project manifest and starter folder structure.
- `:LatexToolsProjectOpen` - locate or open the project manifest for the current buffer.
- `:LatexToolsProjectRender` - render the full project or validate the manifest.
- `:LatexToolsProjectAddFile` - create a new child file and update the manifest.
- `:LatexToolsProjectPickFile` - pick a file from the project tree and open it.
- `:LatexToolsProjectInsertInput` - insert an `\input{...}` or `\include{...}` line.
- `:LatexToolsProjectSyncLabels` - scan all project files for labels and references.
- `:LatexToolsProjectTree` - open the side pane tree editor.
- `:LatexToolsProjectSaveTree` - commit the draft YAML tree.
- `:LatexToolsProjectRestoreTree` - restore the last saved or autosaved draft.

Keep the current commands unchanged:

- `:LatexToolsAssignment` remains the single-document workflow.
- `:LatexToolsSnippet`, `:LatexToolsFigure`, `:LatexToolsTable`, and similar helpers continue to work inside any file.

## Lua Module Split

The current structure can evolve without breaking the public API.

- `assignment.lua` keeps the existing single-template workflow.
- `project.lua` handles project discovery, manifest editing, tree traversal, and project-specific commands.
- `state.lua` gains project path helpers and manifest resolution.
- `references.lua` can optionally accept a project root so it scans all files in the tree.
- `tex_snippets.lua` provides the pattern for recursive discovery and picker labeling.

## Rendering Flow

The project renderer should behave like this:

1. Read the manifest.
2. Resolve the project root and child file paths.
3. Load the root template and any child file templates or stubs.
4. Render metadata into the relevant files.
5. Write output files only when the user explicitly chooses a generation action.

Two rendering strategies are reasonable:

- Template-first: generate the root file and any missing child files from starter templates.
- Synchronization-first: preserve existing user files and only update manifest-driven metadata or stubs.

For this plugin, synchronization-first is safer because it respects user edits.

## Editor Workflow

The user experience should feel like this:

- Initialize a project in an empty directory.
- Pick a document type such as report, lab, or thesis.
- Generate a root file and a set of child files.
- Navigate between child files through a picker.
- Insert `\input{...}` lines from the picker without guessing paths.
- Render or validate the whole tree when needed.

## Integration Points

The existing code already suggests where this belongs:

- `state.get_paths()` can grow project path helpers.
- `commands.lua` and `keymaps.lua` can register project commands and mappings.
- `python/render_template.py` can be extended or paired with a new renderer for project manifests.
- `tests/templates_spec.lua` can gain fixtures for multi-file project setup and rendering.
- `util.lua` can be reused for file listing, slug generation, and text insertion.
- A new `project.lua` module can own the tree model, draft persistence, and structure mutations.
- A small renderer utility can turn YAML tree nodes into `\input{...}` lines for `input.tex`.

## Backward Compatibility Rules

- The current assignment flow must remain the default.
- Existing user files under `~/.config/nvim/latex-tools/` must keep working.
- Project mode should be opt-in and driven by a manifest.
- If no manifest exists, the plugin should behave exactly as it does today.

## Suggested Implementation Phases

### Phase 1: Discovery and manifest support

- Add project root detection.
- Add YAML manifest loading.
- Add `:LatexToolsProjectOpen` and `:LatexToolsProjectInit`.

### Phase 2: File tree commands

- Add add-file, pick-file, and insert-input commands.
- Reuse recursive file listing and relative labels.

### Phase 3: Rendering and validation

- Add project rendering for root plus child files.
- Add manifest validation and clearer error messages.

### Phase 4: Workspace-wide references

- Scan the full project tree for labels, citations, and bibliography entries.
- Make picker lists project-aware instead of buffer-only.

### Phase 5: Tests and docs

- Add fixtures for nested includes and manifest-driven rendering.
- Document the workflow in `README.md` after the feature stabilizes.

## Design Notes

- Prefer explicit manifests over heuristic discovery when the two conflict.
- Use relative paths in the manifest so the project stays portable.
- Keep the root file as the anchor for build and navigation actions.
- Treat child files as normal LaTeX buffers, not a special editor mode.

## Minimal First Version

If the project mode needs to start small, the first useful version is:

- one manifest file,
- one root file,
- one generated `input.tex` body file,
- a picker to create/open child files,
- a side pane tree editor with move up/down/in/out,
- automatic insertion of `\input{...}` lines,
- and workspace-wide label lookup.

That delivers a real multifile workflow without forcing a full build-system redesign.

## Recommendation Summary

The design that best matches your goals is:

- YAML as the canonical hierarchy store.
- Stable node IDs plus `parent_id` and `order` fields.
- A side-pane tree editor in Neovim for structural edits.
- A generated `input.tex` body file.
- `main.tex` as the stable preamble and document shell.
- Draft-buffer editing with explicit commit and restore commands.

If you later want SQL-like query power, add SQLite as a cache or index, not as the primary authoring format.