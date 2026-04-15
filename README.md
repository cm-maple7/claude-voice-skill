# Claude Voice Skill

A `/voice` slash command for [Claude Code](https://claude.com/claude-code) that speaks each of Claude's responses aloud using OpenAI TTS — with a free fallback to the built-in macOS `say` voice if no OpenAI key is set.

When voice mode is on, Claude silently writes a short spoken version of each response to a temp file. A Stop hook then reads that file, synthesizes speech, and plays it through `afplay`. You never see the spoken text in chat — just hear it.

## Pair it with a dictation app for full voice chat

This skill only handles the **assistant side** of a voice conversation — text-to-speech for Claude's responses. To close the loop and actually talk to Claude hands-free, pair it with a dictation app that handles speech-to-text on your side.

I use [Wispr Flow](https://wisprflow.ai/) — I dictate into the Claude Code input, Claude speaks the reply back through this skill, and I keep going. Any system-wide dictation tool works (macOS built-in dictation, [Whisper](https://github.com/openai/whisper)-based tools, etc.), but Wispr Flow is where this setup really shines.

Put another way: this skill alone is one-way. The skill plus a dictation app is the actual "voice mode" experience.

## Install

One command:

```bash
git clone https://github.com/cm-maple7/claude-voice-skill ~/.claude/skills/voice
```

Then open any Claude Code session and type `/voice`. The first time you invoke it, Claude will detect that the skill isn't fully wired up and walk you through a one-time setup:

1. Ask permission to patch your `~/.claude/settings.json` with a Stop hook.
2. Make the playback script executable.
3. Offer to store an OpenAI API key in your macOS Keychain (optional — you can skip and use the free macOS voice).

You confirm each step in the chat. No manual file editing required.

After setup, **restart your Claude Code session once** so it picks up the new hook. Then `/voice` works.

## Usage

- `/voice on` — turn voice mode on for the rest of the conversation
- `/voice off` — turn it off
- `/voice status` — check whether it's currently active
- `/voice repeat` — repeat the most recent spoken response from cached audio (no API call, no cost)
- `/voice stop` — immediately kill any in-progress audio playback

Voice mode does **not** persist across conversations. You invoke `/voice on` at the start of each session you want spoken.

### Repeat

If you miss what was said, `/voice repeat` re-plays the last response from a cached MP3 in `/tmp` — no new OpenAI request. Only the most recent response is cached; the cache is cleared on reboot.

## Requirements

- macOS (uses `security`, `afplay`, `say`)
- [Claude Code](https://claude.com/claude-code)
- Optional: an [OpenAI API key](https://platform.openai.com/api-keys) for higher-quality TTS

## How it works

1. When voice is on, Claude writes a short spoken version of each response to `/tmp/claude_speak.txt` (in addition to the normal on-screen response).
2. When Claude's turn ends, the Stop hook runs [`speak.sh`](speak.sh) in the background.
3. `speak.sh` atomically claims the file, reads your OpenAI key from Keychain via `security find-generic-password`, POSTs to `https://api.openai.com/v1/audio/speech`, and plays the resulting MP3 via `afplay`.
4. If the key is missing or the API call fails, it falls back to `say -v "Ava (Premium)"`.

Logs are written to `/tmp/claude_speak.log` if you want to debug.

**Your API key is never stored in any file in this repo or in your Claude config.** It lives only in macOS Keychain, and `speak.sh` reads it fresh on each invocation.

## Adding or changing your OpenAI key later

```bash
security add-generic-password -s "openai_api_key" -a "$USER" -w "sk-YOUR-KEY-HERE" -U
```

The `-U` flag updates the existing entry if there is one.

## Customizing the voice

Edit [`speak.sh`](speak.sh) to change:

- **OpenAI voice**: change `"voice":"echo"` to `alloy`, `fable`, `onyx`, `nova`, or `shimmer`
- **Speed**: change `"speed":1.05`
- **Model**: change `"model":"tts-1"` to `"tts-1-hd"` for higher quality (roughly 2x the cost)
- **Fallback voice**: change `-v "Ava (Premium)"` to any voice listed by `say -v '?'`

## Cost

OpenAI `tts-1` is billed per character. The skill instructs Claude to aggressively cut filler from spoken output, so most responses are short, but heavy use will still add up. Check usage at [platform.openai.com/usage](https://platform.openai.com/usage).

## Manual install (if the first-run flow fails)

If for some reason Claude can't complete the auto-install, you can do it by hand:

1. Make the script executable: `chmod +x ~/.claude/skills/voice/speak.sh`
2. Add this block to `~/.claude/settings.json` under `hooks`:

   ```json
   {
     "hooks": {
       "Stop": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "nohup $HOME/.claude/skills/voice/speak.sh >/dev/null 2>&1 </dev/null &"
             }
           ]
         }
       ]
     }
   }
   ```

3. (Optional) Store your OpenAI key: `security add-generic-password -s "openai_api_key" -a "$USER" -w "sk-..." -U`
4. Restart Claude Code.

## License

MIT
