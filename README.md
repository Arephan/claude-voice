# Claude Voice

Give Claude Code a voice. Every response spoken aloud, instantly — fully local, free, offline.

Built on [Kokoro TTS](https://github.com/hexgrad/kokoro), a lightweight open-source TTS model that runs on Apple Silicon with near-zero latency.

## Requirements

- macOS with Apple Silicon (M1/M2/M3/M4)
- Python 3.10 (Kokoro doesn't support 3.11+ yet)
- [Claude Code](https://github.com/anthropics/claude-code) installed

---

## Install as a Claude Code Plugin (recommended)

**Step 1** — Add this to your `~/.claude/settings.json`:

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

**Step 2** — Inside Claude Code, run:

```
/plugins add claude-voice@arephan
```

**Step 3** — Run the setup skill:

```
/setup
```

Claude will install everything automatically. That's it — from now on, every response is spoken aloud.

**Slash commands available after install:**
- `/setup` — install or reinstall
- `/voice` — change voice, speed, or troubleshoot

---

## Manual Install

```bash
git clone https://github.com/arephan/claude-voice.git
cd claude-voice
chmod +x install.sh
./install.sh
```

The installer:
- Creates a Python 3.10 virtualenv with Kokoro + dependencies
- Installs the server and hook scripts to `~/bin`
- Registers a launchd service (auto-starts on login, restarts on crash)
- Registers the Stop hook in `~/.claude/settings.json`
- Adds a `shh` alias to stop speech mid-sentence

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

---

## Voices

Default is `af_heart`. To change it, edit `~/bin/kokoro-server.py` and restart the server, or use the `/voice` skill.

**American English (female):** `af_heart` `af_bella` `af_jessica` `af_nova` `af_sky` `af_sarah` `af_nicole` `af_alloy` `af_aoede` `af_kore` `af_river`

**American English (male):** `am_adam` `am_echo` `am_eric` `am_liam` `am_michael` `am_onyx` `am_puck`

**British English:** `bf_alice` `bf_emma` `bf_isabella` `bf_lily` `bm_daniel` `bm_fable` `bm_george` `bm_lewis`

Other languages: Japanese, Chinese, Spanish, French, Hindi, Italian, Portuguese.

## Speed

Default is `1.15`. Range: `0.8` (slow) → `1.5` (fast). Edit `KOKORO_SPEED` in `~/bin/kokoro-server.py` and restart.

```bash
launchctl unload ~/Library/LaunchAgents/com.kokoro-server.plist
launchctl load ~/Library/LaunchAgents/com.kokoro-server.plist
```

## Stop speech mid-sentence

```bash
shh
```

Or set a global hotkey: System Settings → Keyboard → Keyboard Shortcuts → Services → "Stop Kokoro Speech".

## Logs & troubleshooting

```bash
tail -f /tmp/kokoro-server.log
```

Common issues:
- `python3.10 not found` → `brew install python@3.10`
- No socket at `/tmp/kokoro-tts.sock` → check logs above
- No audio → check macOS audio output in System Settings

---

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

**Step 3 — Verify**
```bash
ls /tmp/kokoro-tts.sock
tail -3 /tmp/kokoro-server.log   # Should say "Model loaded and warm. Listening."
```

**Step 4 — Test**
```bash
python3 -c "
import socket, json
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('/tmp/kokoro-tts.sock')
s.sendall(json.dumps({'cmd': 'speak', 'text': 'Claude voice is working!'}).encode())
s.close()
"
```

If the user hears audio — done. Tell them to run `source ~/.zshrc` to get the `shh` alias.
