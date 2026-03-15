#!/usr/bin/env python3
"""Persistent Kokoro TTS server — keeps model warm, streams audio instantly."""
import json
import os
import queue
import re
import signal
import socket
import sys
import threading

os.environ["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"

import warnings
warnings.filterwarnings("ignore")

import numpy as np
import sounddevice as sd
from kokoro import KPipeline

SOCKET_PATH = "/tmp/kokoro-tts.sock"
DEFAULT_VOICE = os.environ.get("KOKORO_VOICE", "af_heart")
DEFAULT_SPEED = float(os.environ.get("KOKORO_SPEED", "1.15"))
pipeline = None
play_lock = threading.Lock()
stop_event = threading.Event()


def clean_for_speech(text):
    text = re.sub(r'```[\s\S]*?```', '', text)
    text = re.sub(r'`[^`]+`', '', text)
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    text = re.sub(r'[#*_~>|]', '', text)
    text = re.sub(r'^\s*[-]\s+', '', text, flags=re.MULTILINE)
    text = re.sub(r'\n{2,}', '. ', text)
    text = re.sub(r'\n', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def make_chunks(text):
    """First sentence alone for fast start, then groups of 3 for natural flow."""
    parts = re.split(r'(?<=[.!?])\s+', text)
    parts = [p.strip() for p in parts if p.strip()]
    if not parts:
        return []
    chunks = [parts[0]]
    for i in range(1, len(parts), 3):
        chunks.append(' '.join(parts[i:i+3]))
    return chunks


def speak(text, voice=None, speed=None):
    global pipeline
    text = clean_for_speech(text)
    if not text or len(text) < 3:
        return

    if len(text) > 2000:
        text = text[:2000] + "... I'll stop reading here."

    voice = voice or DEFAULT_VOICE
    speed = speed or DEFAULT_SPEED
    chunks = make_chunks(text)
    if not chunks:
        return

    audio_queue = queue.Queue(maxsize=4)
    synth_done = threading.Event()

    def synthesize():
        for chunk in chunks:
            if stop_event.is_set():
                break
            for _, _, audio in pipeline(chunk, voice=voice, speed=speed):
                if stop_event.is_set():
                    break
                audio_queue.put(audio)
        synth_done.set()

    stop_event.clear()
    with play_lock:
        t = threading.Thread(target=synthesize, daemon=True)
        t.start()

        stream = sd.OutputStream(samplerate=24000, channels=1, dtype='float32')
        stream.start()
        try:
            while True:
                if stop_event.is_set():
                    break
                try:
                    audio = audio_queue.get(timeout=0.05)
                    audio = audio.cpu().numpy() if hasattr(audio, 'cpu') else audio
                    if audio.ndim == 1:
                        audio = audio.reshape(-1, 1)
                    stream.write(audio.astype(np.float32))
                except queue.Empty:
                    if synth_done.is_set() and audio_queue.empty():
                        break
        finally:
            stream.stop()
            stream.close()


def handle_client(conn):
    try:
        data = b""
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            data += chunk
        conn.close()

        msg = json.loads(data.decode("utf-8"))
        cmd = msg.get("cmd", "speak")

        if cmd == "stop":
            stop_event.set()
            sd.stop()
            return

        if cmd == "ping":
            return

        text = msg.get("text", "")
        voice = msg.get("voice")
        speed = msg.get("speed")
        if text:
            stop_event.set()
            sd.stop()
            t = threading.Thread(target=speak, args=(text, voice, speed), daemon=True)
            t.start()
    except Exception as e:
        print(f"[kokoro-server] error: {e}", file=sys.stderr)


def cleanup(*_):
    try:
        os.unlink(SOCKET_PATH)
    except OSError:
        pass
    sys.exit(0)


def main():
    global pipeline

    print("[kokoro-server] Loading Kokoro model...", file=sys.stderr)
    pipeline = KPipeline(lang_code='a')
    for _, _, audio in pipeline("ready", voice=DEFAULT_VOICE, speed=1.0):
        pass
    print("[kokoro-server] Model loaded and warm. Listening.", file=sys.stderr)

    try:
        os.unlink(SOCKET_PATH)
    except OSError:
        pass

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(5)
    os.chmod(SOCKET_PATH, 0o777)

    print(f"[kokoro-server] Listening on {SOCKET_PATH}", file=sys.stderr)

    while True:
        conn, _ = server.accept()
        threading.Thread(target=handle_client, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
