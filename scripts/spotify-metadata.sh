#!/bin/bash

# =========================
# Configuration
# =========================
FIFO="/mnt/pipe/spotify.metadata"
ART_CACHE="/tmp/spotify_current_art.jpg"
LOG_TAG="spotify-metadata"

# =========================
# 1. THE GATEKEEPER
# =========================
PLAYER_EVENT="${PLAYER_EVENT:-}"
if [[ "$PLAYER_EVENT" != "track_changed" && "$PLAYER_EVENT" != "metadata" ]]; then
    exit 0
fi

sleep 0.5
[ -z "${NAME:-}" ] && exit 0

# =========================
# 2. Helpers & Base64
# =========================
b64_text() { printf "%s" "$1" | base64 -w 0; }
b64_file() { [ -f "$1" ] && base64 -w 0 "$1"; }

add_item() {
    local type="$1" code="$2" data="$3" is_file="${4:-false}"
    local b64 bin_len

    if [ "$is_file" = true ]; then
        [ ! -f "$data" ] && return
        b64=$(b64_file "$data")
        bin_len=$(stat -c%s "$data")
    else
        [ -z "$data" ] || [ "$data" = "null" ] && return
        b64=$(b64_text "$data")
        bin_len=${#data}
    fi

    # Exactly matching the C code sscanf and fscanf logic
    printf "<item><type>%s</type><code>%s</code><length>%u</length>\n" "$type" "$code" "$bin_len"
    printf "<data encoding=\"base64\">%s</data></item>\n" "$b64"
}

# =========================
# 3. Data Extraction
# =========================
CORE="636f7265"
SSNC="73736e63"

TITLE_HEX="6d696e6d"
ARTIST_HEX="61736172"
ALBUM_HEX="6173616l"
GENRE_HEX="6173676e"
ALBUM_ARTIST_HEX="61617274"
TRACK_NUM_HEX="74726b6e"
DURATION_HEX="6173746m"
PICT_HEX="50494354"

# =========================
# 4. Artwork Logic (High-Res)
# =========================
# Reverting to the first URL (640x640)
ART_URL=$(echo "${COVERS:-}" | tr -s ' ' '\n' | head -n 1 | xargs)

if [ -n "$ART_URL" ] && [[ "$ART_URL" == http* ]]; then
    # Download with a generous timeout for larger files
    curl -s -f --connect-timeout 3 --max-time 10 -o "$ART_CACHE" "$ART_URL"
fi

# =========================
# 5. Push to FIFO
# =========================
if [ -p "$FIFO" ]; then
    {
        add_item "$CORE" "$TITLE_HEX"  "$NAME"
        add_item "$CORE" "$ARTIST_HEX" "$ARTISTS"
        add_item "$CORE" "$ALBUM_HEX"  "$ALBUM"
        add_item "$CORE" "$GENRE_HEX"  "${GENRE:-}"
        add_item "$CORE" "$ALBUM_ARTIST_HEX" "${ALBUM_ARTISTS:-}"
        add_item "$CORE" "$TRACK_NUM_HEX"    "${NUMBER:-}"
        add_item "$CORE" "$DURATION_HEX"     "${DURATION_MS:-}"

        # Add the Picture (PICT)
        if [ -s "$ART_CACHE" ]; then
            add_item "$SSNC" "$PICT_HEX" "$ART_CACHE" true
        fi
    } > "$FIFO"
    logger -t "$LOG_TAG" "Pushed high-res metadata for $NAME"
fi
