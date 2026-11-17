#!/usr/bin/env bash
#
# Installs the BIMCraft plugin bimcraft-scripts 0.3.0 into the user's plugins folder.
#
# Run it from the delivery site:
#     curl -fsSL <site>/v1/install.sh | bash
#
# Environment:
#     BIMCRAFT_PLUGINS          the plugins folder to use; an empty value means plugins are off
#     BIMCRAFT_INSTALL_YES      set to 1 to skip the confirmation prompt (automation)
#     BIMCRAFT_INSTALL_NO_PAUSE set to 1 to skip the final pause
#
# The archive is checked against its SHA-256 before anything lands where the application
# reads plugins. Every earlier copy of the same plugin is removed from the plugins folder:
# BIMCraft reads every subfolder that has plugin.json, so a leftover copy makes it report
# a second plugin with the same id as broken.
#
# Requires Bash 4+, curl, and unzip or bsdtar.

set -euo pipefail

PLUGIN_ID='bimcraft-scripts'
PLUGIN_VERSION='0.3.0'
ARCHIVE_URL='https://github.com/dronov-dmitry/bimcraft-run-scripts/releases/download/v0.3.0/bimcraft-scripts-0.3.0.zip'
ARCHIVE_SHA256='2a79de997d4e74e259644b45482a470b7b5839785b886d221d748d30ef462db9'

WORK=''
STAGING=''
DESTINATION=''

say() {
    printf '%s\n' "$*"
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

on_exit() {
    local status=$?
    trap - EXIT
    if [ -n "$STAGING" ] && [ -d "$STAGING" ]; then
        rm -rf "$STAGING"
    fi
    if [ -n "$WORK" ] && [ -d "$WORK" ]; then
        rm -rf "$WORK"
    fi
    if [ -t 0 ] && [ -z "${CI:-}" ] && [ "${BIMCRAFT_INSTALL_NO_PAUSE:-}" != "1" ]; then
        printf 'Press Enter to close this window...'
        read -r _ || true
    fi
    exit "$status"
}

trap on_exit EXIT

require() {
    command -v "$1" >/dev/null 2>&1 || fail "$1 is required but was not found in PATH"
}

plugins_folder() {
    if [ "${BIMCRAFT_PLUGINS+set}" = "set" ]; then
        [ -n "$BIMCRAFT_PLUGINS" ] || fail "BIMCRAFT_PLUGINS is empty: plugins are disabled on this machine"
        printf '%s' "$BIMCRAFT_PLUGINS"
        return 0
    fi
    case "$(uname -s)" in
        Linux)
            printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/bimcraft/plugins"
            ;;
        Darwin)
            printf '%s' "$HOME/Library/Application Support/BIMCraft/plugins"
            ;;
        *)
            fail "unsupported system: $(uname -s); unpack the archive into the plugins folder by hand"
            ;;
    esac
}

confirm() {
    local target=$1
    local answer=''
    if [ "${BIMCRAFT_INSTALL_YES:-}" = "1" ]; then
        return 0
    fi
    [ -r /dev/tty ] || fail "there is no terminal to confirm the install; set BIMCRAFT_INSTALL_YES=1 to install without a prompt"
    printf 'Install %s %s into %s? [Y/n] ' "$PLUGIN_ID" "$PLUGIN_VERSION" "$target" > /dev/tty
    read -r answer < /dev/tty || fail 'no confirmation was read'
    case "$answer" in
        '' | y | Y | yes | YES) return 0 ;;
        *) fail 'the user cancelled the install' ;;
    esac
}

digest_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 -r "$1" | awk '{print $1}'
    else
        fail 'no SHA-256 tool found: install coreutils or openssl'
    fi
}

# Reads the value of the first "id" in a manifest. The host puts the plugin id before the
# functions, and a function id is never the plugin id, so the first match is the right one.
manifest_id() {
    awk '
        match($0, /"id"[[:space:]]*:[[:space:]]*"[^"]*"/) {
            value = substr($0, RSTART, RLENGTH)
            sub(/^.*:[[:space:]]*"/, "", value)
            sub(/"$/, "", value)
            print value
            exit
        }
    ' "$1" 2>/dev/null || true
}

owns_plugin() {
    local folder=$1
    [ -f "$folder/plugin.json" ] || return 1
    [ "$(manifest_id "$folder/plugin.json")" = "$PLUGIN_ID" ]
}

# Removes every earlier copy of this plugin from the plugins folder. A copy left next to the
# new one is read as a second plugin with the same id, and BIMCraft lists it as broken.
remove_earlier_installs() {
    local target=$1
    local path=''
    local name=''
    while IFS= read -r -d '' path; do
        [ "$path" != "$STAGING" ] || continue
        name=${path##*/}
        case "$name" in
            "$PLUGIN_ID" | "$PLUGIN_ID".backup-* | "$PLUGIN_ID".old-*) ;;
            *)
                owns_plugin "$path" || continue
                ;;
        esac
        rm -rf -- "$path"
        say "Removed the earlier install: $path"
    done < <(find "$target" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
}

main() {
    require curl
    local unpacker=''
    if command -v unzip >/dev/null 2>&1; then
        unpacker='unzip'
    elif command -v bsdtar >/dev/null 2>&1; then
        unpacker='bsdtar'
    else
        fail 'unzip is required but was not found in PATH'
    fi

    local target=''
    target="$(plugins_folder)"

    say "Plugin:  $PLUGIN_ID $PLUGIN_VERSION"
    say "Folder:  $target"
    say "Archive: $ARCHIVE_URL"
    confirm "$target"

    WORK="$(mktemp -d)"
    local archive="$WORK/plugin.zip"
    local unpacked="$WORK/unpacked"
    local actual=''

    say 'Downloading...'
    curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --output "$archive" "$ARCHIVE_URL"

    actual="$(digest_of "$archive")"
    if [ "$actual" != "$ARCHIVE_SHA256" ]; then
        fail "the archive does not match its SHA-256: got $actual, expected $ARCHIVE_SHA256; nothing was installed"
    fi

    if [ "$unpacker" = 'unzip' ]; then
        unzip -q "$archive" -d "$unpacked"
    else
        mkdir -p "$unpacked"
        bsdtar -xf "$archive" -C "$unpacked"
    fi
    [ -f "$unpacked/plugin.json" ] || fail 'the archive has no plugin.json; nothing was installed'

    mkdir -p "$target"
    DESTINATION="$target/$PLUGIN_ID"

    # The new copy waits inside the plugins folder under a temporary name, so the final
    # move is a rename on the same filesystem: either the new install is in place or the
    # folder is unchanged.
    STAGING="$target/.tmp-install-$PLUGIN_ID-$$"
    rm -rf -- "$STAGING"
    mv "$unpacked" "$STAGING"

    remove_earlier_installs "$target"
    mv "$STAGING" "$DESTINATION"
    STAGING=''

    say ''
    say "Installed: $DESTINATION"
    say 'Restart BIMCraft: plugins are read when the application starts.'
}

main
