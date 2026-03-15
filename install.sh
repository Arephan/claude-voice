#!/bin/bash
set -e

# Claude Voice — installer
# Speaks Claude Code responses aloud using Kokoro TTS (local, free, offline)

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/bin"
VENV_DIR="$HOME/kokoro-env"
PLIST="$HOME/Library/LaunchAgents/com.kokoro-server.plist"
SETTINGS="$HOME/.claude/settings.json"

echo ""
echo "🎙  Claude Voice Installer"
echo "──────────────────────────"
echo ""

# 1. Check for Python 3.10
echo "→ Checking for Python 3.10..."
PYTHON=""
for candidate in python3.10 python3 python; do
    if command -v "$candidate" &>/dev/null; then
        version=$("$candidate" --version 2>&1 | grep -o '3\.10')
        if [ "$version" = "3.10" ]; then
            PYTHON=$(command -v "$candidate")
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    echo ""
    echo "❌  Python 3.10 is required but not found."
    echo "    Install it with: brew install python@3.10"
    echo "    Then re-run this installer."
    exit 1
fi
echo "   Found: $PYTHON"

# 2. Create virtualenv
echo "→ Creating Python virtualenv at $VENV_DIR..."
if [ ! -d "$VENV_DIR" ]; then
    "$PYTHON" -m venv "$VENV_DIR"
fi

# 3. Install Python dependencies
echo "→ Installing kokoro, sounddevice, numpy, soundfile..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet kokoro sounddevice numpy soundfile

# 4. Copy scripts to ~/bin
echo "→ Installing scripts to $BIN_DIR..."
mkdir -p "$BIN_DIR"

VENV_PYTHON="$VENV_DIR/bin/python3"

for script in kokoro-server.py claude-speak.py; do
    dest="$BIN_DIR/$script"
    cp "$REPO_DIR/$script" "$dest"
    # Write correct shebang
    sed -i.bak "1s|.*|#!$VENV_PYTHON|" "$dest" && rm "$dest.bak"
    chmod +x "$dest"
done

cp "$REPO_DIR/kokoro-stop.sh" "$BIN_DIR/kokoro-stop.sh"
chmod +x "$BIN_DIR/kokoro-stop.sh"

# 5. Add 'shh' alias to stop speech
echo "→ Adding 'shh' alias to ~/.zshrc..."
if ! grep -q "kokoro-stop" "$HOME/.zshrc" 2>/dev/null; then
    echo 'alias shh="~/bin/kokoro-stop.sh"' >> "$HOME/.zshrc"
fi

# 6. Install launchd plist (auto-start on login)
echo "→ Installing launchd service..."
cat > "$PLIST" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.kokoro-server</string>
    <key>ProgramArguments</key>
    <array>
        <string>$VENV_PYTHON</string>
        <string>$BIN_DIR/kokoro-server.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/kokoro-server.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/kokoro-server.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PYTORCH_ENABLE_MPS_FALLBACK</key>
        <string>1</string>
    </dict>
</dict>
</plist>
PLIST_EOF

# Unload if already running
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

# 7. Register Claude Code Stop hook
echo "→ Registering Claude Code Stop hook..."

if [ ! -f "$SETTINGS" ]; then
    mkdir -p "$(dirname "$SETTINGS")"
    echo '{}' > "$SETTINGS"
fi

# Use python to safely merge the hook into settings.json
"$VENV_PYTHON" << PYEOF
import json, sys

path = "$SETTINGS"
hook_cmd = "$BIN_DIR/claude-speak.py"

with open(path) as f:
    settings = json.load(f)

hooks = settings.setdefault("hooks", {})
stop_hooks = hooks.setdefault("Stop", [])

# Check if already registered
already = any(
    h.get("command") == hook_cmd
    for entry in stop_hooks
    for h in entry.get("hooks", [])
)

if not already:
    stop_hooks.append({
        "matcher": "",
        "hooks": [{"type": "command", "command": hook_cmd}]
    })
    with open(path, "w") as f:
        json.dump(settings, f, indent=2)
    print("   Hook registered.")
else:
    print("   Hook already registered, skipping.")
PYEOF

# 8. Wait for server to come up
echo ""
echo "→ Waiting for Kokoro model to load (this takes ~10 seconds)..."
for i in $(seq 1 30); do
    if [ -S "/tmp/kokoro-tts.sock" ]; then
        echo "   Server is ready!"
        break
    fi
    sleep 1
done

echo ""
echo "✅  Done! Claude Code will now speak every response aloud."
echo ""
echo "   Voices:  Edit KOKORO_VOICE in ~/bin/kokoro-server.py"
echo "            Options: af_heart, af_bella, af_jessica, af_nova, af_sky..."
echo "   Speed:   Edit KOKORO_SPEED (default 1.15)"
echo "   Stop:    Type 'shh' in any terminal  (or restart your shell first)"
echo ""
echo "   Logs:    tail -f /tmp/kokoro-server.log"
echo ""
