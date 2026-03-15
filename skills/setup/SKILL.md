---
name: setup
description: Install claude-voice TTS on this machine. Runs the full installer — sets up Kokoro, registers the Stop hook, and starts the server. Use when the user wants to enable voice output for Claude Code.
---

# Claude Voice Setup

Install Kokoro TTS so Claude Code speaks every response aloud.

## Instructions

Run the installer script located at `$CLAUDE_PLUGIN_ROOT/install.sh`. Follow these steps exactly:

### Step 1 — Check Python 3.10
```bash
python3.10 --version
```
If missing: `brew install python@3.10` and wait for it to complete before continuing.

### Step 2 — Run the installer
```bash
bash "$CLAUDE_PLUGIN_ROOT/install.sh"
```

### Step 3 — Verify
```bash
ls /tmp/kokoro-tts.sock && tail -3 /tmp/kokoro-server.log
```
Should show: `Model loaded and warm. Listening.`

### Step 4 — Test
```bash
python3 -c "
import socket, json
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('/tmp/kokoro-tts.sock')
s.sendall(json.dumps({'cmd': 'speak', 'text': 'Claude voice is working!'}).encode())
s.close()
"
```

If the user hears audio — setup is complete. Tell them to reload their shell (`source ~/.zshrc`) to get the `shh` alias for stopping speech.

If there are errors, check `tail -20 /tmp/kokoro-server.log` for details.
