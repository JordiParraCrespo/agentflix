#!/bin/sh
# Copies a finished download into the Plex library.
#
#   sort-media.sh movie  SOURCE_FILE TITLE YEAR    -> /media/movies/Title (Year)/Title (Year).ext
#   sort-media.sh series SOURCE_FILE SHOW SEASON   -> /media/series/Show/Season N/<original name>
#
# If the audio is E-AC3 (unsupported by Chromecast, forcing slow transcoding),
# it's converted to AC3 on the way; otherwise the file is copied as-is.
# Copy, not move, so Transmission keeps seeding the original.
set -eu

MEDIA_ROOT="${MEDIA_ROOT:-/media}"

kind="$1"
src="$2"
ext="${src##*.}"

case "$kind" in
  movie)
    name="$3 ($4)"
    dest_dir="$MEDIA_ROOT/movies/$name"
    dest="$dest_dir/$name.$ext"
    ;;
  series)
    dest_dir="$MEDIA_ROOT/series/$3/Season $4"
    dest="$dest_dir/$(basename "$src")"
    ;;
  *)
    echo "usage: $0 movie|series SOURCE_FILE NAME YEAR|SEASON" >&2
    exit 2
    ;;
esac

if [ -e "$dest" ]; then
  echo "Already in library: $dest"
  exit 0
fi

mkdir -p "$dest_dir"

# Write to a temp name first so Plex never picks up a half-copied file.
tmp="$dest_dir/.partial.$(basename "$dest")"
trap 'rm -f "$tmp"' EXIT

if mediainfo --Inform='Audio;%Format%\n' "$src" | grep -qi 'E-AC-3'; then
  echo "Converting E-AC3 audio to AC3: $src -> $dest"
  ffmpeg -nostdin -loglevel error -y -i "$src" \
    -map 0 -c copy -c:a ac3 -b:a 640k -f "$( [ "$ext" = mp4 ] && echo mp4 || echo matroska )" "$tmp"
else
  echo "Copying: $src -> $dest"
  cp "$src" "$tmp"
fi

mv "$tmp" "$dest"
