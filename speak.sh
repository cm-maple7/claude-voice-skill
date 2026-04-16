#!/bin/bash
# OpenAI TTS playback for Claude Code voice mode.
# Reads /tmp/claude_speak.txt, synthesizes with OpenAI, plays via afplay.
# Uses a lock directory to queue concurrent invocations — if audio is
# already playing, the next invocation waits for it to finish.
# Caches the most recent playback to /tmp/claude_speak_last.{mp3,txt}
# so that `/voice repeat` can re-play it without another API call.

FILE=/tmp/claude_speak.txt
LOG=/tmp/claude_speak.log
LAST_MP3=/tmp/claude_speak_last.mp3
LAST_TXT=/tmp/claude_speak_last.txt
LOCKDIR=/tmp/claude_speak.lockdir
STOP=/tmp/claude_speak.stop

[ -f "$FILE" ] || exit 0

CLAIM=$(mktemp -t claude_speak_claim)
if ! mv "$FILE" "$CLAIM" 2>/dev/null; then
  rm -f "$CLAIM"
  echo "$(date): lost claim race, exiting (pid $$)" >> "$LOG"
  exit 0
fi

TEXT=$(cat "$CLAIM")
if [ -z "$TEXT" ]; then
  rm -f "$CLAIM"
  exit 0
fi

# Wait for any currently-playing instance to finish
while ! mkdir "$LOCKDIR" 2>/dev/null; do
  sleep 0.2
done
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

# If /voice stop was called, abort
if [ -f "$STOP" ]; then
  rm -f "$STOP" "$CLAIM"
  echo "$(date): aborted by stop flag (pid $$)" >> "$LOG"
  exit 0
fi

echo "$(date): playing (pid $$, ${#TEXT} chars)" >> "$LOG"

API_KEY=$(security find-generic-password -s "openai_api_key" -w 2>/dev/null)
if [ -z "$API_KEY" ]; then
  echo "$(date): no openai_api_key in keychain" >> "$LOG"
  cp "$CLAIM" "$LAST_TXT"
  rm -f "$LAST_MP3"
  say -v "Ava (Premium)" -r 200 -f "$CLAIM"
  rm -f "$CLAIM"
  exit 1
fi

PAYLOAD=$(python3 -c 'import json,sys; print(json.dumps({"model":"tts-1","voice":"echo","input":sys.stdin.read(),"speed":1.05}))' < "$CLAIM")

MP3=$(mktemp -t claude_speak).mp3
HTTP_CODE=$(curl -sS -o "$MP3" -w "%{http_code}" https://api.openai.com/v1/audio/speech \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [ "$HTTP_CODE" = "200" ] && [ -s "$MP3" ]; then
  cp "$MP3" "$LAST_MP3"
  cp "$CLAIM" "$LAST_TXT"
  afplay "$MP3"
else
  echo "$(date): openai tts failed (http $HTTP_CODE)" >> "$LOG"
  cat "$MP3" >> "$LOG" 2>/dev/null
  echo "" >> "$LOG"
  cp "$CLAIM" "$LAST_TXT"
  rm -f "$LAST_MP3"
  say -v "Ava (Premium)" -r 200 -f "$CLAIM"
fi

rm -f "$MP3" "$CLAIM"
