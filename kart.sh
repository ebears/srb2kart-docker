#!/bin/bash

if [ ! -x /SRB2/bin/lsdl2srb2kart ]; then
    echo "ERROR: /SRB2/bin/lsdl2srb2kart not found or not executable"
    exit 1
fi

# Validate required game data files
REQUIRED_FILES=(srb2.srb gfx.kart textures.kart chars.kart maps.kart music.kart sounds.kart mdls.dat)
MISSING=()
for f in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "/SRB2/$f" ]; then
        MISSING+=("$f")
    fi
done
if [ ${#MISSING[@]} -gt 0 ]; then
    echo "ERROR: Missing required game data files:"
    for f in "${MISSING[@]}"; do
        echo "  - $f"
    done
    echo "Available files in /SRB2/:"
    ls -la /SRB2/
    exit 1
fi

# Fix volume permissions if running as root
if [ "$(id -u)" = "0" ]; then
    mkdir -p /data/.srb2kart
    [ ! -f /data/.srb2kart/kartserv.cfg ] && cp /defaults/kartserv.cfg /data/.srb2kart/kartserv.cfg
    chown -R srb2kart:srb2kart /data
    exec gosu srb2kart "$0" "$@"
fi

shopt -s nullglob
ADDONS=(/mods/*)
shopt -u nullglob

# Filter to recognized addon file types only
FILTERED_ADDONS=()
for f in "${ADDONS[@]}"; do
    case "$f" in
        *.wad|*.pk3|*.kart|*.soc|*.lua|*.cfg)
            FILTERED_ADDONS+=("$f") ;;
    esac
done

EXTRA=()
[ "${#FILTERED_ADDONS[@]}" -gt 0 ] && EXTRA=(-file "${FILTERED_ADDONS[@]}")

# Startup logging
echo "=== SRB2 Kart Dedicated Server ==="
echo "Binary: /SRB2/bin/lsdl2srb2kart"
if [ ${#FILTERED_ADDONS[@]} -gt 0 ]; then
    echo "Mods (${#FILTERED_ADDONS[@]}):"
    for a in "${FILTERED_ADDONS[@]}"; do
        echo "  - $(basename "$a")"
    done
else
    echo "Mods: none"
fi
echo "Extra args: $*"
echo "=================================="

child_pid=""
child_exit=0

forward_signal() {
    if [ -n "$child_pid" ]; then
        kill -"$1" "$child_pid" 2>/dev/null
        wait "$child_pid"
        child_exit=$?
    fi
    exit "$child_exit"
}

trap 'forward_signal TERM' SIGTERM
trap 'forward_signal INT' SIGINT

/SRB2/bin/lsdl2srb2kart -dedicated -config kartserv.cfg -home /data "${EXTRA[@]}" "$@" &
child_pid=$!
wait "$child_pid"
child_exit=$?

exit "$child_exit"
