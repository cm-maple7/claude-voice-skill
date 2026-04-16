---
name: voice
description: Toggle voice mode. When ON, every assistant response silently writes a short spoken version to /tmp/claude_speak.txt for a Stop hook to play via TTS. Supports repeating the most recent spoken response without re-calling the API, and immediate interruption of in-progress playback. On first invocation, walks the user through installing the required Stop hook into their Claude settings and (optionally) storing an OpenAI API key. Use when the user invokes /voice, /voice on, /voice off, /voice status, /voice repeat, or /voice stop.
---

# Voice Mode

The user has invoked `/voice`.

## Step 0 — First-run install check

Before acting on the toggle, verify the skill is installed. Read `~/.claude/settings.json` and look in `hooks.Stop` or `hooks.PostToolUse` for any command referencing `speak.sh`.

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

**3. Patch `~/.claude/settings.json` to add the hooks.**

Read the file and parse it as JSON. Merge in two hook entries **without clobbering any existing config**:

- If the top-level `hooks` key does not exist, create it.
- If `hooks.PostToolUse` does not exist, create it as an empty array. Append this entry (the `matcher` ensures it only fires after Write tool calls):

```json
{
  "matcher": "Write",
  "hooks": [
    {
      "type": "command",
      "command": "nohup $HOME/.claude/skills/voice/speak.sh >/dev/null 2>&1 </dev/null &"
    }
  ]
}
```

- If `hooks.Stop` does not exist, create it as an empty array. Append this entry (acts as a fallback in case the PostToolUse hook misses anything):

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

The PostToolUse hook is the primary trigger — it fires immediately after Claude writes the speech file, so playback starts mid-response instead of waiting for Claude to finish. The Stop hook is a safety net that catches anything the PostToolUse hook missed. The script's atomic claim mechanism prevents double-play if both hooks fire for the same file.

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
- **`repeat`** → repeat the most recent spoken response from cached audio (no API call, no cost). See the Repeat section below.
- **`stop`** → immediately kill any in-progress audio playback. See the Stop playback section below.

Acknowledge the toggle in **one short sentence** (e.g. "Voice mode on.", "Voice mode off.", "Repeating.", "Audio stopped."). Do not produce a spoken summary for the acknowledgment itself.

---

## When voice mode is ON

For **every response from this point forward** in the conversation, until the user invokes `/voice off`:

1. Write the normal detailed response as you normally would (file references, code, bullets, headers — whatever the response calls for). This is what the user reads on screen.
2. **Do not** append a divider. **Do not** print a spoken paragraph in the chat. The user does not need to see it — they can read the detailed response above.
3. Use the Write tool to save a short spoken version (plain prose only) to `/tmp/claude_speak.txt`. A Stop hook reads that file, speaks it via macOS `say`, and deletes it. If you skip this step, nothing plays.

Do this on every response while voice mode is ON, even short ones. The only exception is the toggle acknowledgment itself.

### Rules for the spoken text

**Conversational flow — one topic at a time.** When voice mode is on, the user is in a dialogue — they hear your response and speak their reply. Multi-topic responses force them to mentally juggle several threads and compose a verbal answer covering all of them at once. That doesn't work.

This rule applies to both the on-screen response AND the spoken text:

- Address one topic, question, or decision per response. If the user's prompt touches multiple things, handle the most important or most blocking one first. You will get to the rest in subsequent turns.
- Do not present multiple options and ask the user to choose among them. State your recommendation and why, then ask if they want something different.
- Keep responses short enough that the user can hold the whole thing in working memory and respond to it verbally.

This does not mean withhold information or be unhelpfully terse. If a single topic genuinely requires depth, give it depth. The rule is about breadth, not depth: one thing thoroughly, not four things shallowly.

**Length — cut fluff, not substance.** Voice output is going through a paid TTS API billed per character, and it is listened to in real time. Every wasted word costs money and wastes the user's attention. But "concise" does not mean "short regardless of the question" — it means the answer contains no filler. A genuinely complex answer is allowed to be long if the length is doing real work. A simple answer must not be padded to sound thorough.

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

## Repeat

If the user invokes `/voice repeat`, repeat the most recent spoken response from the cached audio — **no new API call, no cost**.

The playback script caches each successful response to `/tmp/claude_speak_last.mp3` (OpenAI-generated) and `/tmp/claude_speak_last.txt` (the source text). Play this cache directly using the Bash tool:

```bash
if [ -s /tmp/claude_speak_last.mp3 ]; then
  (nohup afplay /tmp/claude_speak_last.mp3 >/dev/null 2>&1 &)
  echo "replay_mp3"
elif [ -s /tmp/claude_speak_last.txt ]; then
  (nohup say -v "Ava (Premium)" -r 200 -f /tmp/claude_speak_last.txt >/dev/null 2>&1 &)
  echo "replay_say"
else
  echo "replay_none"
fi
```

Based on the output, respond with **one short sentence**:

- `replay_mp3` → "Repeating."
- `replay_say` → "Repeating with the fallback voice."
- `replay_none` → "Nothing to repeat yet."

**Important:** On a repeat turn, **do not** write anything to `/tmp/claude_speak.txt`, even if voice mode is ON. Writing to that file would cause the Stop hook to make a brand-new OpenAI API call when your response ends, which is exactly what repeat is meant to avoid. The user just wants to re-hear what they already heard — your acknowledgment sentence does not need to be spoken.

---

## Stop playback

If the user invokes `/voice stop`, immediately kill any in-progress audio. This covers both the OpenAI path (`afplay` playing an MP3) and the macOS fallback (`say`).

Run this Bash command:

```bash
touch /tmp/claude_speak.stop
rm -f /tmp/claude_speak.txt
pkill -x afplay 2>/dev/null; a=$?
pkill -x say 2>/dev/null; s=$?
if [ "$a" -eq 0 ] || [ "$s" -eq 0 ]; then
  echo "stopped"
else
  echo "nothing"
fi
```

The stop flag (`/tmp/claude_speak.stop`) tells any queued instance of `speak.sh` to abort instead of playing. The script checks for this flag after acquiring the playback lock. Removing the pending text file prevents any unclaimed speech from being picked up.

Based on the output, respond with **one short sentence**:

- `stopped` → "Audio stopped."
- `nothing` → "Nothing was playing."

**Important:** On a stop turn, **do not** write anything to `/tmp/claude_speak.txt`, even if voice mode is ON. Writing to that file would queue up a brand-new response to be spoken the moment the Stop hook fires at the end of your turn — immediately undoing the thing the user just asked for. The acknowledgment does not need to be spoken.

---

## Status

If the user invokes `/voice status`, report whether voice mode is currently active in this conversation (based on whether you've been ending responses with the spoken paragraph). One sentence.

---

## Persistence

Voice mode persists for the rest of the current conversation once turned on. It does **not** carry over to future conversations — the user invokes `/voice on` at the start of each voice session.
