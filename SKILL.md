---
name: voice
description: Toggle voice mode. When ON, every assistant response silently writes a short spoken version to /tmp/claude_speak.txt for a Stop hook to play via TTS. Use when the user invokes /voice, /voice on, /voice off, or /voice status.
---

# Voice Mode

The user has invoked `/voice`. Look at the argument they passed:

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
