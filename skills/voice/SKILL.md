---
name: voice
description: Control claude-voice TTS settings — change voice, speed, stop speech, or restart the server. Use when user wants to adjust how Claude sounds.
---

# Claude Voice Control

Manage the Kokoro TTS server settings.

## Change Voice

Edit `~/bin/kokoro-server.py` and change the `DEFAULT_VOICE` line, then restart:
```bash
launchctl unload ~/Library/LaunchAgents/com.kokoro-server.plist
launchctl load ~/Library/LaunchAgents/com.kokoro-server.plist
```

Or set via env var in the plist: `KOKORO_VOICE=af_bella`

**American English female:** af_heart, af_bella, af_jessica, af_nova, af_sky, af_sarah, af_nicole, af_alloy, af_aoede, af_kore, af_river
**American English male:** am_adam, am_echo, am_eric, am_liam, am_michael, am_onyx, am_puck
**British English:** bf_alice, bf_emma, bf_isabella, bf_lily, bm_daniel, bm_fable, bm_george, bm_lewis

To preview a voice before committing:
```bash
python3 -c "
import socket, json
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect('/tmp/kokoro-tts.sock')
s.sendall(json.dumps({'cmd': 'speak', 'text': 'Hi, this is what I sound like.', 'voice': 'af_bella'}).encode())
s.close()
"
```

## Change Speed

Edit `KOKORO_SPEED` in `~/bin/kokoro-server.py`. Default is `1.15`. Range: `0.8` (slow) to `1.5` (fast). Restart server after changing.

## Stop Speech

```bash
~/bin/kokoro-stop.sh
# or if alias is loaded:
shh
```

## Restart Server

```bash
launchctl unload ~/Library/LaunchAgents/com.kokoro-server.plist && launchctl load ~/Library/LaunchAgents/com.kokoro-server.plist
```

## Check Status

```bash
tail -5 /tmp/kokoro-server.log
ls /tmp/kokoro-tts.sock
```
