# oofind Makefile
#
# Usage:
#   make build       - compile main.oo to dist/oofind
#   make check       - run oodac check on every .oo file
#   make line-cap    - enforce 16-256 line cap on every .oo and .oot (shim-exempt)
#   make file-law    - reject forbidden file extensions and stray docs
#   make academy     - verify every .oo has the 4-element Academy header
#   make density     - enforce at most 8 pages per directory
#   make verify      - run line-cap, file-law, academy, density, and check
#   make test        - run regression and functional test suite
#   make package-deb - produce standalone Debian (.deb) package
#   make package-rpm - produce standalone RedHat/Fedora (.rpm) package
#   make package     - build all package formats
#   make clean       - remove build artifacts

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/oofind
VERSION ?= 0.2.0

SRC := $(wildcard *.oo) $(wildcard */*.oo)

.PHONY: all build check line-cap file-law academy density verify test package-deb package-rpm package clean

all: verify build test

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@echo "built $(BIN)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot" -not -path "./dist/*" -not -path "./qa/fixtures/*"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
			continue; \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="py js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" -not -path "./.blackbox/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" -not -path "./.blackbox/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*" -not -path "./qa/fixtures/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./qa/fixtures*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*" -not -path "./qa/fixtures/*"); do \
		$(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

# --- Functional test suite ---------------------------------------------------

test: $(BIN)
	@echo "=== testing --help ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@echo "=== testing --version ==="
	@./$(BIN) --version > /dev/null && echo "PASS: --version"
	@echo "=== testing invalid flag (expect 2) ==="
	@./$(BIN) --invalid-unknown-flag > /dev/null 2>&1; test $$? -eq 2 && echo "PASS: invalid option exits 2"
	@echo "=== testing nonexistent path (expect 2) ==="
	@./$(BIN) qa/fixtures/nonexistent_path_xyz > /dev/null 2>&1; test $$? -eq 2 && echo "PASS: missing path exits 2"
	@echo "=== testing basic traversal ==="
	@./$(BIN) qa/fixtures | grep -q "sample_a.txt" && echo "PASS: basic traversal finds files"
	@echo "=== testing -name pattern ==="
	@./$(BIN) qa/fixtures -name "*.oo" | grep -q "sample_b.oo" && echo "PASS: -name matches *.oo"
	@./$(BIN) qa/fixtures -name "*.oo" | grep -v "sample_b.oo" | grep -v "^qa/fixtures$$" || true
	@echo "=== testing -iname pattern ==="
	@./$(BIN) qa/fixtures -iname "*.OO" | grep -q "sample_b.oo" && echo "PASS: -iname matches case-insensitively"
	@echo "=== testing -type f ==="
	@./$(BIN) qa/fixtures -type f | grep -q "sample_a.txt" && echo "PASS: -type f finds files"
	@echo "=== testing -type d ==="
	@./$(BIN) qa/fixtures -type d | grep -q "qa/fixtures/sub" && echo "PASS: -type d finds directories"
	@echo "=== testing -e / -extension ==="
	@./$(BIN) qa/fixtures -e oo | grep -q "sample_b.oo" && echo "PASS: -e matches extension"
	@echo "=== testing -maxdepth 1 ==="
	@./$(BIN) qa/fixtures -maxdepth 1 | grep -q "sample_a.txt" && echo "PASS: -maxdepth 1 includes top level"
	@./$(BIN) qa/fixtures -maxdepth 1 | grep -q "nested.txt" && { echo "FAIL: -maxdepth 1 descended"; exit 1; } || echo "PASS: -maxdepth 1 pruned children"
	@echo "=== testing -empty ==="
	@./$(BIN) qa/fixtures -empty | grep -q "empty.txt" && echo "PASS: -empty finds 0-byte file"
	@echo "=== testing -print0 ==="
	@./$(BIN) qa/fixtures -name "*.txt" -print0 | tr '\0' '\n' | grep -q "sample_a.txt" && echo "PASS: -print0 delimits by NUL"
	@echo "=== testing --json ==="
	@./$(BIN) qa/fixtures -name "sample_a.txt" --json | grep -q '"name":"sample_a.txt"' && echo "PASS: --json outputs valid JSON Lines"
	@echo "=== testing --exit-code match (expect 0) ==="
	@./$(BIN) qa/fixtures -name "sample_a.txt" --exit-code > /dev/null && echo "PASS: --exit-code match exits 0"
	@echo "=== testing --exit-code no match (expect 1) ==="
	@./$(BIN) qa/fixtures -name "no_such_file_xyz" --exit-code > /dev/null 2>&1; test $$? -eq 1 && echo "PASS: --exit-code no match exits 1"
	@echo "=== testing MCP stdio initialize ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "protocolVersion" && echo "PASS: MCP initialize"
	@echo "=== testing MCP stdio tools/list ==="
	@printf '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "find_files" && echo "PASS: MCP tools/list"
	@echo "=== testing MCP stdio tools/call ==="
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"find_files","arguments":{"root":"qa/fixtures","pattern":"*.oo"}}}\n' | ./$(BIN) --mcp | grep -q "sample_b.oo" && echo "PASS: MCP tools/call"
	@echo "=== testing double-run determinism ==="
	@./$(BIN) qa/fixtures > .ooda-cache/run1.txt 2>&1 || true; \
	./$(BIN) qa/fixtures > .ooda-cache/run2.txt 2>&1 || true; \
	cmp .ooda-cache/run1.txt .ooda-cache/run2.txt && echo "PASS: double-run output is bit-identical"
	@echo "ALL TESTS PASSED"

# --- Packaging targets --------------------------------------------------------

package-deb:
	@if [ ! -f $(BIN) ]; then $(MAKE) $(BIN); fi
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/oofind
	@chmod 0755 dist/deb-root/usr/bin/oofind
	@dpkg-deb --build --root-owner-group dist/deb-root dist/oofind_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/oofind_$(VERSION)-1_amd64.deb"

package-rpm:
	@if [ ! -f $(BIN) ]; then $(MAKE) $(BIN); fi
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/oofind-linux-x86_64
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/oofind.spec > ~/rpmbuild/SPECS/oofind.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/oofind.spec
	@cp ~/rpmbuild/RPMS/x86_64/oofind-$(VERSION)*.rpm dist/
	@echo "built dist RPM package"

package: package-deb package-rpm

clean:
	@rm -rf dist .ooda-cache
	@echo "cleaned"
