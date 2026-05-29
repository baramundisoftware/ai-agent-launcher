#!/usr/bin/env bash
# copilot-launcher.sh — Run GitHub Copilot CLI sandboxed via bubblewrap (WSL/Ubuntu x64)
set -euo pipefail

ALLOWED_PATHS=("$HOME/source/")
SANDBOX="$HOME/.claude-sandbox"

# Detect if we're inside bwrap by checking if PID 1 is bwrap
if [[ "$(cat /proc/1/comm 2>/dev/null)" != "bwrap" ]] && [[ "$$" != "2" ]]; then
  # Determine project directory
  PROJECT="$(realpath .)"

  # Check if project is in allowed locations
  allowed=false
  for prefix in "${ALLOWED_PATHS[@]}"; do
    if [[ "${PROJECT,,}" == "${prefix,,}"* ]]; then
      allowed=true
      break
    fi
  done

  if [[ "$allowed" == false ]]; then
    echo "ERROR: '$PROJECT' is not in an allowed location."
    echo "Edit ALLOWED_PATHS to add more locations."
    exit 1
  fi

  # Ask for confirmation
  echo "Project directory: $PROJECT"
  echo -n "Allow Copilot to access this directory? [y/N] "
  read -n 1 -r response && echo
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi

  echo "Preparing sandbox..."
  mkdir -p "$SANDBOX/home"

  # Initialize managed settings
  MANAGED_SETTINGS="$SANDBOX/managed-settings.json"
  if [[ ! -e "$MANAGED_SETTINGS" ]]; then
    echo '{"companyAnnouncements":["Running inside bubblewrap (bwrap) sandbox."]}' > "$MANAGED_SETTINGS"
  fi

  # Build bind mounts
  BINDS=()
  for p in /usr /lib /lib64 /bin /sbin /etc/resolv.conf /etc/ssl /etc/ca-certificates \
       /etc/alternatives /etc/ld.so.cache /etc/localtime /etc/passwd /etc/group \
       /etc/hosts /etc/nsswitch.conf /etc/host.conf; do
    [[ -e "$p" ]] && BINDS+=(--ro-bind "$p" "$p")
  done

  # Re-launch this script inside bwrap
  exec bwrap \
    --unshare-all \
    --share-net \
    --clearenv \
    --new-session \
    --die-with-parent \
    --proc /proc \
    --dev /dev \
    --tmpfs /tmp \
    --tmpfs /run \
    "${BINDS[@]}" \
    --bind "$SANDBOX/home" "$HOME" \
    --bind "$PROJECT" "$PROJECT" \
    --ro-bind "$MANAGED_SETTINGS" /etc/claude-code/managed-settings.json \
    --setenv HOME "$HOME" \
    --setenv TERM "${TERM:-xterm-256color}" \
    --chdir "$PROJECT" \
    --ro-bind "$0" /entrypoint \
    -- /entrypoint "$@"
fi

# ====== Everything below runs inside bwrap ======

echo "Inside sandbox. Checking for updates..."

# Fix access to tools for MCP servers
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

COPILOT_BIN="$HOME/.local/bin/copilot"
PLATFORM="linux"
ARCH="x64"

remote_ver="$(curl -fsSI https://github.com/github/copilot-cli/releases/latest 2>/dev/null \
  | grep -i '^location:' | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')"
remote_ver="${remote_ver#v}"
if [[ -z "$remote_ver" ]]; then
  echo "ERROR: could not determine latest version from GitHub. Check network/rate-limit."
  exit 1
fi
echo "Latest: $remote_ver"

needs_update=false
if [[ -x "$COPILOT_BIN" ]]; then
  local_ver="$("$COPILOT_BIN" --version 2>/dev/null || echo "")"
  if [[ "$local_ver" != *"$remote_ver"* ]]; then
    echo "Updating $local_ver to $remote_ver ..."
    needs_update=true
  else
    echo "Up to date."
  fi
else
  echo "Downloading $remote_ver ..."
  needs_update=true
fi

if [[ "$needs_update" == "true" ]]; then
  tmpdir="$(TMPDIR="$HOME" mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  curl -fsSL -o "$tmpdir/copilot.tar.gz" \
    "https://github.com/github/copilot-cli/releases/latest/download/copilot-${PLATFORM}-${ARCH}.tar.gz" \
    || { echo "ERROR: download failed (curl exit $?)"; exit 1; }
  tar -xzf "$tmpdir/copilot.tar.gz" -C "$tmpdir"
  mv "$tmpdir/copilot" "$COPILOT_BIN"
  chmod +x "$COPILOT_BIN"
  trap - EXIT
  rm -rf "$tmpdir"
fi

# Launch copilot with arguments
exec "$COPILOT_BIN" "$@"
