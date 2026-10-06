#!/bin/sh
# ==============================================================================
# oofind Universal Installer
# "Capability-bounded file finding utility for the openOODA era."
#
# Usage:
#   curl -fsSL https://openooda-tools.github.io/oofind/install.sh | bash
#
# Options:
#   --prefix <dir>   Installation directory for standalone binary (default: /usr/local/bin or ~/.local/bin)
#   --deb, --apt     Download and install Debian package (.deb) via apt/dpkg
#   --dnf, --rpm     Download and install RPM package (.rpm) via dnf
#   --pkgbuild, --arch Download and install Arch Linux package via makepkg/PKGBUILD
#   --dry-run        Simulate installation without touching the filesystem
#   --uninstall      Remove oofind from standard system paths
#   -h, --help       Show this help message
# ==============================================================================

set -eu

REPO="openOODA-tools/oofind"
GITHUB_URL="https://github.com/${REPO}"
CANONICAL_URL="https://openooda-tools.github.io/oofind"
VERSION_PIN="v0.2.0"
RAW_VERSION="0.2.0"

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ] && [ "${TERM:-dumb}" != "dumb" ]; then
    CYAN="\033[38;5;51m"
    GREEN="\033[38;5;82m"
    YELLOW="\033[38;5;220m"
    DIM="\033[38;5;242m"
    BOLD="\033[1m"
    RESET="\033[0m"
else
    CYAN="" GREEN="" YELLOW="" DIM="" BOLD="" RESET=""
fi

say()  { printf '%b\n' "$*"; }
ok()   { say "  ${GREEN}✔${RESET} $*"; }
warn() { say "  ${YELLOW}!${RESET} $*"; }
err()  { say "  ${YELLOW}ERROR:${RESET} $*" >&2; }
step() { say ""; say " ${CYAN}${BOLD}$*${RESET}"; }

PREFIX=""
DRY_RUN=0
UNINSTALL=0
INSTALL_DEB=0
INSTALL_DNF=0
INSTALL_ARCH=0

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --deb|--apt)
            INSTALL_DEB=1
            shift
            ;;
        --dnf|--rpm)
            INSTALL_DNF=1
            shift
            ;;
        --pkgbuild|--arch)
            INSTALL_ARCH=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --uninstall)
            UNINSTALL=1
            shift
            ;;
        -h|--help)
            say "Usage: install.sh [options]"
            say "Options:"
            say "  --prefix <dir>       Target installation directory for standalone binary"
            say "  --deb, --apt         Install Debian package (.deb) via apt/dpkg"
            say "  --dnf, --rpm         Install RPM package (.rpm) via dnf"
            say "  --pkgbuild, --arch   Build and install Arch Linux package via PKGBUILD"
            say "  --dry-run            Simulate installation without disk writes"
            say "  --uninstall          Remove oofind from installation path"
            exit 0
            ;;
        *)
            err "Unknown option: $1"
            exit 2
            ;;
    esac
done

if [ "$UNINSTALL" -eq 1 ]; then
    step "Uninstalling oofind"
    if [ "$DRY_RUN" -eq 1 ]; then
        say "  [dry-run] Would remove oofind binary or packages"
        ok "Dry run complete."
        exit 0
    fi

    if command -v dpkg >/dev/null 2>&1 && dpkg -s oofind >/dev/null 2>&1; then
        sudo apt-get remove -y oofind || sudo dpkg -r oofind
        ok "Removed oofind Debian package"
    elif command -v rpm >/dev/null 2>&1 && rpm -q oofind >/dev/null 2>&1; then
        sudo dnf remove -y oofind || sudo rpm -e oofind
        ok "Removed oofind RPM package"
    elif command -v pacman >/dev/null 2>&1 && pacman -Q oofind-bin >/dev/null 2>&1; then
        sudo pacman -R --noconfirm oofind-bin
        ok "Removed oofind Arch package"
    elif command -v pacman >/dev/null 2>&1 && pacman -Q oofind >/dev/null 2>&1; then
        sudo pacman -R --noconfirm oofind
        ok "Removed oofind Arch package"
    fi

    for p in /usr/local/bin/oofind "${HOME}/.local/bin/oofind" /usr/bin/oofind; do
        if [ -f "$p" ]; then
            rm -f "$p" 2>/dev/null || sudo rm -f "$p"
            ok "Removed $p"
        fi
    done
    exit 0
fi

# --- DEB / APT Installation ---
if [ "$INSTALL_DEB" -eq 1 ]; then
    step "Installing oofind via DEB/apt ($VERSION_PIN)"
    DEB_NAME="oofind_${RAW_VERSION}-1_amd64.deb"
    DEB_URL="${GITHUB_URL}/releases/download/${VERSION_PIN}/${DEB_NAME}"
    if [ "$DRY_RUN" -eq 1 ]; then
        say "  [dry-run] Would download $DEB_URL and run sudo dpkg -i"
        ok "Dry run complete."
        exit 0
    fi
    TMP_DEB="$(mktemp --suffix=.deb)"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$DEB_URL" -o "$TMP_DEB"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$TMP_DEB" "$DEB_URL"
    else
        err "Neither curl nor wget available."
        exit 1
    fi
    sudo dpkg -i "$TMP_DEB" || sudo apt-get install -f -y
    rm -f "$TMP_DEB"
    ok "Installed oofind deb package."
    oofind --version
    exit 0
fi

# --- DNF / RPM Installation ---
if [ "$INSTALL_DNF" -eq 1 ]; then
    step "Installing oofind via DNF/rpm ($VERSION_PIN)"
    RPM_NAME="oofind-${RAW_VERSION}-1.x86_64.rpm"
    RPM_URL="${GITHUB_URL}/releases/download/${VERSION_PIN}/${RPM_NAME}"
    if [ "$DRY_RUN" -eq 1 ]; then
        say "  [dry-run] Would install $RPM_URL via dnf"
        ok "Dry run complete."
        exit 0
    fi
    sudo dnf install -y "$RPM_URL"
    ok "Installed oofind RPM package."
    oofind --version
    exit 0
fi

# --- Arch Linux / PKGBUILD Installation ---
if [ "$INSTALL_ARCH" -eq 1 ]; then
    step "Installing oofind via PKGBUILD ($VERSION_PIN)"
    if [ "$DRY_RUN" -eq 1 ]; then
        say "  [dry-run] Would fetch PKGBUILD and execute makepkg -si"
        ok "Dry run complete."
        exit 0
    fi
    if ! command -v makepkg >/dev/null 2>&1; then
        err "makepkg not found. Install base-devel on Arch Linux or install the standalone binary."
        exit 1
    fi
    BUILD_DIR="$(mktemp -d)"
    if [ -f "./packaging/arch/PKGBUILD" ]; then
        cp "./packaging/arch/PKGBUILD" "$BUILD_DIR/PKGBUILD"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "${CANONICAL_URL}/PKGBUILD" -o "$BUILD_DIR/PKGBUILD" || \
        curl -fsSL "${GITHUB_URL}/raw/main/packaging/arch/PKGBUILD" -o "$BUILD_DIR/PKGBUILD"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$BUILD_DIR/PKGBUILD" "${CANONICAL_URL}/PKGBUILD" || \
        wget -qO "$BUILD_DIR/PKGBUILD" "${GITHUB_URL}/raw/main/packaging/arch/PKGBUILD"
    else
        err "Neither curl nor wget available."
        rm -rf "$BUILD_DIR"
        exit 1
    fi
    (cd "$BUILD_DIR" && makepkg -si --noconfirm)
    rm -rf "$BUILD_DIR"
    ok "Installed oofind via PKGBUILD."
    oofind --version
    exit 0
fi

# --- Standalone Binary Installation (Default) ---
resolve_prefix() {
    if [ -n "$PREFIX" ]; then
        return
    fi
    if [ "$(id -u)" -eq 0 ]; then
        PREFIX="/usr/local/bin"
    elif [ -d "$HOME/.local/bin" ] && printf '%s' "$PATH" | grep -q "$HOME/.local/bin"; then
        PREFIX="$HOME/.local/bin"
    elif [ -w "/usr/local/bin" ]; then
        PREFIX="/usr/local/bin"
    else
        PREFIX="$HOME/.local/bin"
    fi
}

resolve_prefix

step "Installing oofind standalone binary ($VERSION_PIN)"
say "  Target location: ${BOLD}$PREFIX/oofind${RESET}"

if [ "$DRY_RUN" -eq 1 ]; then
    say "  [dry-run] Would download and install to $PREFIX/oofind"
    ok "Dry run complete."
    exit 0
fi

mkdir -p "$PREFIX"

if [ -f "./dist/oofind" ]; then
    cp "./dist/oofind" "$PREFIX/oofind"
    chmod +x "$PREFIX/oofind"
    ok "Installed local binary to $PREFIX/oofind"
else
    DOWNLOAD_URL="${GITHUB_URL}/releases/download/${VERSION_PIN}/oofind-linux-x86_64"
    TMP_BIN="$(mktemp)"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$DOWNLOAD_URL" -o "$TMP_BIN"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$TMP_BIN" "$DOWNLOAD_URL"
    else
        err "Neither curl nor wget available."
        exit 1
    fi
    chmod +x "$TMP_BIN"
    mv "$TMP_BIN" "$PREFIX/oofind"
    ok "Downloaded and installed $VERSION_PIN to $PREFIX/oofind"
fi

if "$PREFIX/oofind" --version >/dev/null 2>&1; then
    ok "Verified: $("$PREFIX/oofind" --version)"
else
    warn "Installed binary failed execution check."
fi
