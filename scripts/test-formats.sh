#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
command -v ffmpeg >/dev/null || { echo 'Format integration tests require ffmpeg.'; exit 1; }
FIXTURES="$PWD/.build/audio-fixtures"
mkdir -p "$FIXTURES"
ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=frequency=440:duration=3:sample_rate=44100' -c:a pcm_s16le -y "$FIXTURES/fixture.wav"
for ext in mp3 m4a aiff; do
    ffmpeg -hide_banner -loglevel error -i "$FIXTURES/fixture.wav" -y "$FIXTURES/fixture.$ext"
done
MUSICPILOT_TEST_AUDIO="$FIXTURES" swift test
