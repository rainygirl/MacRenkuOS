#!/bin/bash
# Run RenkuOS arm64 under QEMU on Apple Silicon, from the Terminal:
#
#   curl -fsSL https://raw.githubusercontent.com/rainygirl/MacRenkuOS/main/macrenkuos.sh | bash
#
# or download it and run `bash macrenkuos.sh` / `./macrenkuos.sh` directly.
# No install step, no separate disk: every run boots the same live medium
# (R Chromium included, no Installer on it -- see renku-arm64's arm64-patch
# 0041-0044) off a qcow2 overlay next to the ISO. That overlay is the
# guest's only writable storage and persists across runs -- delete
# ~/Library/Application Support/Renku/renku-arm64-live-overlay.qcow2 to
# reset to a pristine live session.
#
# Each run also checks the GitHub release for a newer image; if one
# exists, it's downloaded and the old overlay is dropped (a new ISO
# invalidates it). No network, or a live session already running: the
# cached ISO/overlay are left alone.
#
# While the guest runs, its boot volume is mounted on the Mac as a network
# volume named RenkuOS (Finder > Locations) -- run-qemu-renku-arm64.sh does
# that, against renku-arm64's arm64-patch 0047; RENKU_SHARE=0 turns it off.
#
# The first run installs itself as a `renkuos` command on PATH, so later
# runs are just `renkuos`.
set -euo pipefail

DATA="$HOME/Library/Application Support/Renku"
mkdir -p "$DATA/tools/qemu-notch"
cd "$DATA"

REPO_RAW="https://raw.githubusercontent.com/rainygirl/renkuos-arm64/main"
ISO="$DATA/renku-arm64-live.iso"
ISO_OVERLAY="$DATA/renku-arm64-live-overlay.qcow2"
ISO_URL="https://github.com/rainygirl/renkuos-arm64/releases/latest/download/renku-arm64-live-current.iso"
TAG_FILE="$DATA/renku-arm64-live.tag"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
	C_INFO=$'\033[1;36m'
	C_ERR=$'\033[1;31m'
	C_RESET=$'\033[0m'
else
	C_INFO=""
	C_ERR=""
	C_RESET=""
fi
info() { printf '%s%s%s\n' "$C_INFO" "$1" "$C_RESET"; }
err() { printf '%s%s%s\n' "$C_ERR" "$1" "$C_RESET" >&2; }

confirm() {
	# Real stdin, since this can run from `curl | bash` (stdin is the pipe,
	# not the terminal) as well as a local checkout.
	read -r -p "$1 [y/N] " reply </dev/tty
	[[ "$reply" =~ ^[Yy]$ ]]
}

SELF_URL="https://raw.githubusercontent.com/rainygirl/MacRenkuOS/main/macrenkuos.sh"

install_self() {
	# Drops a copy of this script as the `renkuos` command on a directory
	# already on PATH, so later runs are just `renkuos` instead of the full
	# curl | bash line. Best-effort and silent on failure -- this is a
	# convenience, not something the rest of the script depends on.
	local dir=""
	for d in /opt/homebrew/bin "$HOME/.local/bin"; do
		if [ -d "$d" ] && [ -w "$d" ]; then
			dir="$d"
			break
		fi
	done
	[ -n "$dir" ] || { mkdir -p "$HOME/.local/bin" 2>/dev/null && dir="$HOME/.local/bin"; }
	[ -n "$dir" ] || return 0

	local target="$dir/renkuos"
	local first_install=1
	[ -x "$target" ] && first_install=0

	if curl -fsSL --max-time 5 -o "$target.part" "$SELF_URL"; then
		mv "$target.part" "$target"
		chmod +x "$target"
	else
		rm -f "$target.part"
		return 0
	fi

	if [ "$first_install" = 1 ]; then
		info "Installed the 'renkuos' command -- next time, just run: renkuos"
		case ":$PATH:" in
			*":$dir:"*) ;;
			*) info "Add $dir to your PATH to use it." ;;
		esac
	fi
}
install_self

info "Checking for QEMU"
if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
	if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ]; then
		confirm "RenkuOS needs Homebrew to install QEMU. Install it now?" \
			|| { err "Can't continue without Homebrew."; exit 1; }
		NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi
	eval "$(/opt/homebrew/bin/brew shellenv)"
	confirm "RenkuOS needs QEMU (brew install qemu). Install it now?" \
		|| { err "Can't continue without QEMU."; exit 1; }
	brew install qemu
fi

info "Fetching the QEMU launcher"
curl -fsSL -o run-qemu-renku-arm64.sh "$REPO_RAW/run-qemu-renku-arm64.sh"
chmod +x run-qemu-renku-arm64.sh
curl -fsSL -o tools/qemu-notch/qemu-notch.m "$REPO_RAW/tools/qemu-notch/qemu-notch.m"
curl -fsSL -o tools/qemu-notch/build.sh "$REPO_RAW/tools/qemu-notch/build.sh"
chmod +x tools/qemu-notch/build.sh

check_for_update() {
	# Don't yank the ISO out from under an already-running live session.
	if pgrep -f "qemu-system-aarch64.*renku-arm64-live-overlay" >/dev/null 2>&1; then
		return
	fi

	local latest=""
	latest="$(curl -fsSL --max-time 5 \
		https://api.github.com/repos/rainygirl/renkuos-arm64/releases/latest \
		| grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')" || true
	[ -n "$latest" ] || return 0   # offline, or the API call failed -- keep the cache

	local current=""
	[ -f "$TAG_FILE" ] && current="$(cat "$TAG_FILE")"
	if [ -s "$ISO" ] && [ "$latest" = "$current" ]; then
		return 0
	fi

	info "Downloading the RenkuOS live image ($latest, ~310MB)"
	if curl -fL --retry 3 --max-time 600 -o "$ISO.part" "$ISO_URL"; then
		mv "$ISO.part" "$ISO"
		rm -f "$ISO_OVERLAY"   # a new ISO invalidates the old overlay
		echo "$latest" >"$TAG_FILE"
	else
		rm -f "$ISO.part"
		err "Download failed; keeping the cached image."
	fi
}
check_for_update

if [ ! -s "$ISO" ]; then
	err "No cached RenkuOS image and the download failed."
	exit 1
fi

export RENKU_ISO="$ISO"
export LIVE_DISK_GB="${LIVE_DISK_GB:-16}"
info "Booting RenkuOS"
exec ./run-qemu-renku-arm64.sh --live
