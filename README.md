# oofind

> **Capability-bounded file finding utility for the openOODA era.**  
> *A drop-in `find` replacement written in pure openOODA, featuring an agent-native MCP surface.*

Part of [openOODA-tools](https://github.com/openOODA-tools).

---

## 1. Quick Install

Zero runtime dependencies. The binary is pure native, statically linked with host libc.

### Web Installer
```bash
curl -fsSL https://openooda-tools.github.io/oofind/install.sh | bash
```

#### Installer Options
```bash
# Preview actions without modifying the host
curl -fsSL https://openooda-tools.github.io/oofind/install.sh | bash -s -- --dry-run

# Install to custom directory
curl -fsSL https://openooda-tools.github.io/oofind/install.sh | bash -s -- --prefix /usr/bin

# Uninstall
curl -fsSL https://openooda-tools.github.io/oofind/install.sh | bash -s -- --uninstall
```

### APT (Debian / Ubuntu)
```bash
# Install deb package from releases
sudo dpkg -i oofind_0.1.0-1_amd64.deb
```

### DNF / RPM (Fedora / RHEL / openSUSE)
```bash
# Install rpm package from releases
sudo dnf install oofind-0.1.0-1.x86_64.rpm
```

---

## 2. Two Faces, One Engine

`oofind` serves both human developers in terminal pipelines and autonomous LLM coding agents. Both surfaces share the exact same traversal, matching, and filtering engines.

| Surface | Invocation | Audience | Description |
| :--- | :--- | :--- | :--- |
| **CLI** | `oofind [paths...] [predicates...]` | Humans, shell pipes, `xargs` | Recursive file search with globbing, type filtering, `-print0`, and JSON streaming. |
| **MCP** | `oofind --mcp` | LLM agents over stdio | JSON-RPC 2.0 Model Context Protocol server exposing `find_files` and `find_entries`. |

---

## 3. Usage

```
usage: oofind [paths...] [options]
Search for files in a directory hierarchy.

Matching:
  -name PATTERN        match basename against glob pattern
  -iname PATTERN       match basename against case-insensitive glob pattern
  -type [f|d|l]        filter by entry kind: f (file), d (directory), l (symlink)
  -e, -extension EXT   filter by file extension (e.g. oo, txt, rs)
  -empty               match empty files (0 bytes) or empty directories
  -size [+|-]N[k|M|G]  filter by file size (bytes, or k/M/G suffixes)

Traversing:
  -maxdepth NUM        maximum directory depth to descend (default: unlimited)
  -mindepth NUM        minimum depth required to emit entry (default: 0)
  -hidden, --hidden    include hidden files and directories (starting with '.')
  --no-ignore          do not respect .gitignore rules

Output:
  -print0              delimit output entries by NUL (\0) instead of newline
  --json               emit results as JSON Lines records
  --exit-code          exit with 0 if matches found, 1 if no matches found
  --mcp                run in Model Context Protocol mode over stdio
  -h, --help           display this help and exit
  -v, -V, --version    output version information and exit
```

### Examples

#### Find files matching a name pattern
```bash
oofind . -name "*.oo"
```

#### Find only regular files with an extension
```bash
oofind src -type f -e oo
```

#### Bounded depth search
```bash
oofind . -maxdepth 2 -name "Makefile"
```

#### Find large files
```bash
oofind /var/log -type f -size +10M
```

#### Pipeline integration with xargs -0
```bash
oofind src -name "*.oo" -print0 | xargs -0 wc -l
```

#### JSON Lines stream for tooling
```bash
oofind . -name "*.oo" --json
```

---

## 4. Exit Code Contract

| Exit Code | Meaning | Context |
| :--- | :--- | :--- |
| `0` | Clean traversal | Traversal finished without error (or matches found under `--exit-code`). |
| `1` | No matches found | Emitted only when `--exit-code` flag is specified and zero files match. |
| `2` | Trouble / Fault | Invalid flags, non-existent roots, or unreadable directories. |

---

## 5. Architecture: The Four Domains

The codebase is strictly structured into four isolated domains under openOODA House Laws:

```
main.oo          CLI argument routing, pipeline dispatch, and exit status
anchor.oo        Root subsystem domain map
walk/            Hierarchy traversal, depth bounding, symlink guard, ignore rules
match/           Pure predicates: globs, case folding, extensions, types, sizes
render/          Standard formatting, -print0 NUL bytes, JSON Lines streaming, help
ipc/             CLI option parser and JSON-RPC 2.0 stdio Model Context Protocol server
```

---

## 6. Verification Gate

```bash
make verify
```

Enforces:
1. `line-cap`: Every `.oo` page is between 16 and 256 lines (shims exempt from floor).
2. `file-law`: Rejects forbidden file extensions and stray documentation.
3. `academy`: Ensures the mandatory 4-element Academy header is present in the first 7 lines.
4. `density`: Enforces $\le 8$ pages per directory.
5. `check`: Verifies `oodac check` passes on every page.

---

## 7. License

Apache License 2.0. Part of the sovereign [openOODA](https://github.com/openOODA) project.
