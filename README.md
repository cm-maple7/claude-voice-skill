# Claude Voice Skill

A `/voice` skill for [Claude Code](https://claude.com/claude-code) that speaks each of Claude's responses aloud using OpenAI TTS (with a fallback to the built-in macOS `say` command).

When voice mode is on, Claude writes a short, spoken version of every response to a temporary file. A Stop hook then reads that file, synthesizes speech via the OpenAI API, and plays it through `afplay`. If no OpenAI key is configured, it falls back silently to macOS `say` — so the skill works without an OpenAI account.

Toggle with `/voice on`, `/voice off`, or `/voice status`.

## Requirements

- macOS (uses `security`, `afplay`, `say`)
- [Claude Code](https://claude.com/claude-code)
- Optional: an [OpenAI API key](https://platform.openai.com/api-keys) for higher-quality TTS

## Install

### 1. Install the skill

```bash
mkdir -p ~/.claude/skills/voice
cp SKILL.md ~/.claude/skills/voice/SKILL.md
```

### 2. Install the playback script

```bash
mkdir -p ~/.claude/scripts
cp speak.sh ~/.claude/scripts/speak.sh
chmod +x ~/.claude/scripts/speak.sh
```

### 3. Add the Stop hook to `~/.claude/settings.json`

Merge this block into your `settings.json`. If you already have a `hooks` section, add the `Stop` entry alongside your existing hooks.

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "nohup /Users/YOUR_USERNAME/.claude/scripts/speak.sh >/dev/null 2>&1 </dev/null &"
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your macOS username (or use `$HOME` expansion if your shell supports it in hook contexts).

### 4. (Optional) Store your OpenAI API key in macOS Keychain

```bash
security add-generic-password -s "openai_api_key" -a "$USER" -w "sk-..."
```

The script reads the key at runtime via `security find-generic-password -s "openai_api_key" -w`. **The key is never written to any file in this repo or your Claude config.**

If you skip this step, the skill falls back to macOS `say` with the "Ava (Premium)" voice.

## Usage

In any Claude Code conversation:

- `/voice on` — turn voice mode on for the rest of the conversation
- `/voice off` — turn it off
- `/voice status` — check whether voice mode is currently active

Voice mode does **not** persist across conversations — you invoke `/voice on` at the start of each session you want spoken.

## How it works

1. When voice is on, Claude writes a short spoken version of each response to `/tmp/claude_speak.txt` (in addition to the normal on-screen response).
2. When Claude's turn ends, the Stop hook runs `speak.sh` in the background.
3. `speak.sh` atomically claims the file, reads your OpenAI key from Keychain, POSTs to `https://api.openai.com/v1/audio/speech`, and plays the resulting MP3 via `afplay`.
4. If the key is missing or the API call fails, it falls back to `say -v "Ava (Premium)"`.

Logs are written to `/tmp/claude_speak.log`.

## Customizing the voice

Edit [`speak.sh`](speak.sh) to change:

- **OpenAI voice**: change `"voice":"echo"` to `alloy`, `fable`, `onyx`, `nova`, or `shimmer`
- **Speed**: change `"speed":1.05`
- **Model**: change `"model":"tts-1"` to `"tts-1-hd"` for higher quality (costs more)
- **Fallback voice**: change `-v "Ava (Premium)"` to any voice from `say -v '?'`

## Cost

OpenAI `tts-1` is billed per character. The skill is designed to keep spoken output short — Claude is instructed to cut fluff aggressively — but heavy use will still add up. Check your usage at [platform.openai.com/usage](https://platform.openai.com/usage).

## License

MIT
