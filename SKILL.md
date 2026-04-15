---
name: voice
description: Toggle voice mode. When ON, every assistant response silently writes a short spoken version to /tmp/claude_speak.txt for a Stop hook to play via TTS. On first invocation, walks the user through installing the required Stop hook into their Claude settings and (optionally) storing an OpenAI API key. Use when the user invokes /voice, /voice on, /voice off, or /voice status.
---

# Voice Mode

The user has invoked `/voice`.

## Step 0 — First-run install check

Before acting on the toggle, verify the skill is installed. Read `~/.claude/settings.json` and look in `hooks.Stop` for any command referencing `speak.sh`.

- **If found** → the skill is already installed. Skip directly to the toggle logic below.
- **If not found** → this is first-run setup. Execute the install flow, then continue to the toggle logic.

### First-run install flow

Tell the user in one short paragraph:

> It looks like this is the first time you're using the voice skill. To make it work, I need to add a Stop hook to your Claude settings — it runs a small script (included with this skill) after each of my responses to synthesize and play speech. Optionally, I can also help you store an OpenAI API key for higher-quality TTS; without one, it falls back to the built-in macOS voice. Want me to proceed?

Wait for confirmation. If the user declines, stop — do not toggle voice mode.

If they confirm, do the following in order:

**1. Verify the playback script exists.**

The script is at `~/.claude/skills/voice/speak.sh` (the same directory as this `SKILL.md`, since the whole skill is cloned as a unit). Confirm the file is present. If it is missing, tell the user the repo may not have been cloned correctly into `~/.claude/skills/voice/` and stop.

**2. Make it executable.**

Run `chmod +x ~/.claude/skills/voice/speak.sh`.

**3. Patch `~/.claude/settings.json` to add the Stop hook.**

Read the file and parse it as JSON. Merge in a new Stop hook entry **without clobbering any existing config**:

- If the top-level `hooks` key does not exist, create it.
- If `hooks.Stop` does not exist, create it as an empty array.
- Append this entry to `hooks.Stop`:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "nohup $HOME/.claude/skills/voice/speak.sh >/dev/null 2>&1 </dev/null &"
    }
  ]
}
```

Write the file back. Prefer the Edit tool over Write when the file already has content, to minimize the risk of clobbering existing formatting or keys.

**4. Offer to set up an OpenAI API key.**

First check whether a key is already stored: run `security find-generic-password -s "openai_api_key" -w 2>/dev/null`. If it returns a non-empty value, skip this step entirely.

Otherwise, present these three options to the user:

> The playback script can use an OpenAI API key for high-quality TTS (roughly a tenth of a cent per response). Without a key, it falls back to the built-in macOS voice — free, but more robotic. Three options:
>
> 1. **Paste the key here** — I'll store it in your macOS Keychain. Note: the key will be visible in this conversation.
> 2. **Add it yourself in your own terminal** (safer). I'll give you the exact one-line command to run.
> 3. **Skip** — use the macOS fallback voice for now. You can add a key later.

Handle the response:

- **Option 1**: Run `security add-generic-password -s "openai_api_key" -a "$USER" -w "<KEY>" -U` with the key they provided. The `-U` flag updates if the entry exists. Confirm success in one line.
- **Option 2**: Print the exact command for them to run: `security add-generic-password -s "openai_api_key" -a "$USER" -w "sk-YOUR-KEY-HERE" -U`. Tell them to replace the placeholder and run it in their own terminal.
- **Option 3**: Tell them briefly that they can add a key later using the same command from Option 2.

**5. Confirm install is done.**

Tell the user, in one short paragraph:

> Voice skill installed. The Stop hook is now in your Claude settings. Heads up: Claude Code reads hooks at the start of a session, so you will probably need to restart this Claude Code session once for the hook to take effect. After that, voice mode will play audio automatically.

Then proceed to the toggle logic below.

---

## Toggle logic

Look at the argument the user passed:

- **`on`** (or no argument) → turn voice mode ON
- **`off`** → turn voice mode OFF
- **`status`** → report whether voice mode is currently active in this conversation

Acknowledge the toggle in **one short sentence** (e.g. "Voice mode on." or "Voice mode off."). Do not produce a spoken summary for the acknowledgment itself.

---

## When voice mode is ON

For **every response from this point forward** in the conversation, until the user invokes `/voice off`:

1. Write the normal detailed response as you normally would (file references, code, bullets, headers — whatever the response calls for). This is what the user reads on screen.
2. **Do not** append a divider. **Do not** print a spoken paragraph in the chat. The user does not need to see it — they can read the detailed response above.
3. Use the Write tool to save a short spoken version (plain prose only) to `/tmp/claude_speak.txt`. A Stop hook reads that file, speaks it via macOS `say`, and deletes it. If you skip this step, nothing plays.

Do this on every response while voice mode is ON, even short ones. The only exception is the toggle acknowledgment itself.

### Rules for the spoken text

**Length — cut fluff, not substance.** Voice output will soon be going through a paid TTS API billed per character, and it is listened to in real time. Every wasted word costs money and wastes the user's attention. But "concise" does not mean "short regardless of the question" — it means the answer contains no filler. A genuinely complex answer is allowed to be long if the length is doing real work. A simple answer must not be padded to sound thorough.

The test for every sentence: **does cutting this sentence lose information the listener actually needs?** If no, cut it. Apply that test one sentence at a time until every remaining sentence earns its place.

What to cut without hesitation:
- Preamble ("alright", "so", "basically", "what's going on here is")
- Recapping what the user already knows or just said
- Editorializing about how to feel ("the good news is", "you'll be in great shape", "that's the tricky part")
- Warm-ups, sign-offs, softeners, hedges that add no information
- Restating the same point in different words
- Meta-commentary about the answer itself ("to summarize", "in short")

State the answer. Stop. Do not pad to feel complete.

**Format:**
- Plain prose only. No bullets, no sub-headers, no line breaks, no markdown of any kind — no bold, italics, code spans, links, or inline backticks.
- No file paths, line numbers, function names, variable names, flag names, command-line snippets, or URLs.

**Translation, not omission:**
- Translate technical references into spoken English. Instead of naming a specific function, describe what it does ("the click handler in the settings code"). Instead of naming a variable, describe what it represents ("the body weight setting").
- Acronyms: spell them letter by letter or expand them into words — whichever sounds natural. Be consistent within the response.
- Numbers and units stay as words a person would actually say.

**Voice:**
- Matter-of-fact and direct. Competent human delivering information, not a friendly assistant easing in. Contractions are fine.
- Self-contained: someone hearing only the spoken version (without seeing the screen) should still understand what happened or what the answer is.
- Never just "I made the changes you asked for" — say what the changes actually accomplish.

---

## When voice mode is OFF

Stop writing to `/tmp/claude_speak.txt`. Respond normally per the default style guidelines.

---

## Status

If the user invokes `/voice status`, report whether voice mode is currently active in this conversation (based on whether you've been ending responses with the spoken paragraph). One sentence.

---

## Persistence

Voice mode persists for the rest of the current conversation once turned on. It does **not** carry over to future conversations — the user invokes `/voice on` at the start of each voice session.
