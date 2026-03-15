# Claude Voice

Give Claude Code a voice. Every response spoken aloud, instantly — fully local, free, offline.

Built on [Kokoro TTS](https://github.com/hexgrad/kokoro), a lightweight open-source TTS model that runs on Apple Silicon with near-zero latency.

## For AI Agents

> If you're an AI agent helping a user set this up, follow these steps exactly.

**Step 1 — Check requirements**
```bash
python3.10 --version   # Must be 3.10.x — if missing: brew install python@3.10
which claude           # Must be installed
uname -m               # Should be arm64 (Apple Silicon)
```

**Step 2 — Clone and run the installer**
```bash
git clone https://github.com/arephan/claude-voice.git ~/claude-voice
cd ~/claude-voice
chmod +x install.sh
./install.sh
```

The installer is fully automated. It will:
- Create a Python 3.10 virtualenv at `~/kokoro-env`
- Install all dependencies (kokoro, sounddevice, numpy, soundfile)
- Copy `kokoro-server.py` and `claude-speak.py` to `~/bin` with correct shebangs
- Register a launchd service that auto-starts the server on login
- Register the Stop hook in `~/.claude/settings.json`
- Add `shh` alias for interrupting speech

**Step 3 — Verify it worked**
```bash
# Server should be running
ls /tmp/kokoro-tts.sock   # Socket file should exist
tail -3 /tmp/kokoro-server.log   # Should say "Model loaded and warm. Listening."

# Test speech
python3 -c "
import socket, json
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('/tmp/kokoro-tts.sock')
s.sendall(json.dumps({'cmd': 'speak', 'text': 'Hello! Voice is working.'}).encode())
s.close()
"
```

If you hear speech — it's working. Tell the user to reload their shell (`source ~/.zshrc`) to get the `shh` alias.

**Common issues:**
- `python3.10 not found` → `brew install python@3.10`
- Socket doesn't exist after install → `tail -f /tmp/kokoro-server.log` to see the error
- No audio → check macOS audio output device in System Settings

---

## How it works

```
Claude finishes a response
        ↓
Claude Code fires a Stop hook
        ↓
Lightweight hook script (~1ms) sends text over Unix socket
        ↓
Kokoro server (always-on daemon, model pre-loaded in memory)
        ↓
Splits into sentences → synthesizes first sentence immediately
        ↓
Plays through a continuous audio stream while pre-synthesizing the rest
        ↓
You hear Claude speak with no noticeable delay
```

The two-process design (warm daemon + thin hook client) is what makes it fast. No model loading on each response — just a socket send.

## Requirements

- macOS (Apple Silicon recommended — M1/M2/M3/M4)
- Python 3.10 (Kokoro doesn't support 3.11+ yet)
- [Claude Code](https://github.com/anthropics/claude-code) installed

## Install as a Claude Code Plugin (recommended)

Add to your `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "arephan": {
      "source": {
        "source": "github",
        "repo": "arephan/claude-voice"
      }
    }
  }
}
```

Then inside Claude Code run:
```
/plugins add claude-voice@arephan
```

Claude will automatically run the installer on first setup. Use `/setup` to install and `/voice` to manage settings.

## Manual Install

```bash
git clone https://github.com/arephan/claude-voice.git
cd claude-voice
chmod +x install.sh
./install.sh
```

That's it. The installer:
- Creates a Python 3.10 virtualenv with Kokoro + dependencies
- Installs the server and hook scripts to `~/bin`
- Registers the launchd service (auto-starts on login, restarts on crash)
- Registers the Stop hook in `~/.claude/settings.json`
- Adds a `shh` alias to kill speech mid-sentence

## Voices

Default voice is `af_heart`. Change it by setting `KOKORO_VOICE` in the launchd plist, or editing the default in `~/bin/kokoro-server.py`.

**American English (female):** `af_heart` `af_bella` `af_jessica` `af_nova` `af_sky` `af_sarah` `af_nicole` `af_alloy` `af_aoede` `af_kore` `af_river`

**American English (male):** `am_adam` `am_echo` `am_eric` `am_liam` `am_michael` `am_onyx` `am_puck`

**British English:** `bf_alice` `bf_emma` `bf_isabella` `bf_lily` `bm_daniel` `bm_fable` `bm_george` `bm_lewis`

Other languages available too (Japanese, Chinese, Spanish, French, Hindi, Italian, Portuguese).

## Speed

Default speed is `1.15`. Adjust `KOKORO_SPEED` or edit the default in `~/bin/kokoro-server.py`. Range: `0.8` (slow) to `1.5` (fast).

After changing voice or speed, restart the server:

```bash
launchctl unload ~/Library/LaunchAgents/com.kokoro-server.plist
launchctl load ~/Library/LaunchAgents/com.kokoro-server.plist
```

## Stop speech mid-sentence

```bash
shh
```

Or set up a global keyboard shortcut: System Settings → Keyboard → Keyboard Shortcuts → Services → find "Stop Kokoro Speech".

## Logs

```bash
tail -f /tmp/kokoro-server.log
```

## Manual server control

```bash
# Stop
launchctl unload ~/Library/LaunchAgents/com.kokoro-server.plist

# Start
launchctl load ~/Library/LaunchAgents/com.kokoro-server.plist

# Test
python3 -c "
import socket, json
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('/tmp/kokoro-tts.sock')
s.sendall(json.dumps({'cmd': 'speak', 'text': 'Hello, this is a test.'}).encode())
s.close()
"
```
