# Claude Voice

Give Claude Code a voice. Every response spoken aloud, instantly — fully local, free, offline.

Built on [Kokoro TTS](https://github.com/hexgrad/kokoro), a lightweight open-source TTS model that runs on Apple Silicon with near-zero latency.

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

## Install

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
