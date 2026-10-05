# oofind: House Laws & Agent Engineering Standards (v1)

This document is the **single canonical source of truth** for all code, architecture, and system integration standards across `oofind`. Every human contributor and AI agent must strictly follow these rules without exception.

---

## 1. What oofind Is

A capability-bounded recursive file finding tool for the openOODA ecosystem. It traverses directory hierarchies, evaluates filtering predicates, and renders matching entries to terminal pipelines, null-delimited streams (`-print0`), machine-readable JSON (`--json`), and agent-native stdio MCP sessions (`--mcp`).

It adheres strictly to the POSIX exit-code contract:

| Exit | Meaning |
|---|---|
| `0` | Traversal succeeded cleanly (or matches found under `--exit-code`) |
| `1` | No matches found (under `--exit-code` pipeline mode) |
| `2` | Trouble / fault: invalid flags, unreadable roots, or permission denial |

---

## 2. The Four Domains

Work lands in exactly one domain at a time. Each domain owns a specific responsibility:

| Domain | Responsibility | Does NOT Do |
|---|---|---|
| `walk/` | Hierarchy traversal, depth bounding, symlink guard, ignore rules | Filter criteria or render text |
| `match/` | Predicates (globs, extensions, types, sizes, empty tests) | Touch filesystem or format output |
| `render/` | Formatting paths, null-delimited records, JSON streaming, help | Traverse filesystem or evaluate filters |
| `ipc/` | CLI flag parsing and JSON-RPC 2.0 stdio MCP server | Re-implement traversal or matching |

---

## 3. The Page Rule (Code Layout & Sizing)

A **page** is one committed `.oo` or `.oot` file. Automated verification gates enforce these rules under `make verify`:

- **16–256 Lines**: Every committed source file must be between **16 and 256 lines**, counted as exact line breaks.
- **Shim Exemption (Floor Only)**: A file is a shim when every non-comment line is an import (`import "..."`). Shims skip the 16-line floor. The **256-line ceiling still applies without exception**.
- **Directory Density ($\le 8$ files)**: At most **8 `.oo` / `.oot` files per directory**, tests included.
- **Banned File Names**: Never name a page `util.oo`, `utils.oo`, `helper.oo`, `helpers.oo`, `common.oo`, `misc.oo`, `shared.oo`, `base.oo`, or `core.oo`. Name the verb or wholly owned noun.
- **Imports**: All imports must be relative string literals (e.g. `import "walk/anchor.oo";`). Never use `::` namespaces.

---

## 4. The 4-Element Academy Header (Mandatory on Every Page)

Every committed `.oo` file must begin with the standard 4-element Academy docstring within the first 7 lines:

```oo
// # Component Name - Subtitle
//
// Logline: Single-sentence imperative summary of functional responsibility.
//
// Setup: Preconditions, wired capability tokens, imported contracts.
//
// Beats:
//   1. First sequential phase of execution.
//   2. Next phase.
//   3. Final phase / exit state.
```

---

## 5. Capability Discipline & Security Model

`oofind` operates strictly on the Object-Capability (OCap) security model:

- **Zero Ambient Authority**: `oofind` never touches the filesystem without an explicit `&FsReadCap` passed from `main`. It holds no `&FsWriteCap` and never opens network sockets.
- **Read-Only by Construction**: Finding files requires only read access. The absence of `&FsWriteCap` and `&NetCap` in `main` is static enforcement.
- **Subprocess Safety**: Never spawn child processes or invoke `/bin/sh -c`. `main` declares `&ProcessCap` solely to raise non-zero exit status via `process_exit`.
- **Symlink Cycle Defense**: Traversal detects directory symlink loops and avoids infinite recursion.
- **Negative-Trust Boundaries**: Inputs are validated and bounds-checked. Double-run determinism is required: two runs over an unchanged tree produce bit-identical output.

---

## 6. Verification Gate

Before any commit or release, run:

```bash
make verify
```

Runs `line-cap`, `file-law`, `academy`, `density`, and `check` (`oodac check`). All must pass.
