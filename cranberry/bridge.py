"""Client for the loopback socket that Cariberry.app hosts.

Cariberry (Swift) is the long-running process, so it listens; we connect to
it, retrying quietly if it isn't up yet. Everything is newline-delimited
JSON, one object per line. See Sources/DesktopPup/CranberryBridge.swift for
the other end of this protocol.
"""

from __future__ import annotations

import json
import socket
import threading
import time
import uuid
from typing import Optional

from . import config


class CariberryBridge:
    """Talks to the running Cariberry.app over 127.0.0.1.

    Safe to use even when Cariberry isn't running yet or gets restarted:
    every call reconnects lazily and swallows connection errors, since
    Cranberry should degrade gracefully (e.g. print instead of animate) when
    its host app isn't around.
    """

    def __init__(self, host: str = config.BRIDGE_HOST, port: int = config.BRIDGE_PORT):
        self._host = host
        self._port = port
        self._sock: Optional[socket.socket] = None
        self._lock = threading.Lock()
        self._pending: dict[str, threading.Event] = {}
        self._results: dict[str, str] = {}
        self._reader_thread: Optional[threading.Thread] = None

    # -- connection management -------------------------------------------------

    def _ensure_connected(self) -> Optional[socket.socket]:
        with self._lock:
            if self._sock is not None:
                return self._sock
            try:
                sock = socket.create_connection((self._host, self._port), timeout=1.5)
            except OSError:
                return None
            self._sock = sock
            self._reader_thread = threading.Thread(target=self._read_loop, args=(sock,), daemon=True)
            self._reader_thread.start()
            return sock

    def _drop(self, sock: socket.socket) -> None:
        with self._lock:
            if self._sock is sock:
                self._sock = None
        try:
            sock.close()
        except OSError:
            pass

    def wait_for_cariberry(self, timeout: Optional[float] = None) -> bool:
        """Blocks (with quiet retries) until Cariberry.app accepts a connection."""
        start = time.monotonic()
        while self._ensure_connected() is None:
            if timeout is not None and time.monotonic() - start > timeout:
                return False
            time.sleep(1.0)
        return True

    # -- reading ---------------------------------------------------------------

    def _read_loop(self, sock: socket.socket) -> None:
        buffer = b""
        try:
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                buffer += chunk
                while b"\n" in buffer:
                    line, buffer = buffer.split(b"\n", 1)
                    if line:
                        self._handle_line(line)
        except OSError:
            pass
        finally:
            self._drop(sock)

    def _handle_line(self, line: bytes) -> None:
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            return
        if message.get("type") == "transcribed":
            request_id = message.get("id")
            text = message.get("text", "")
            if request_id in self._pending:
                self._results[request_id] = text
                self._pending[request_id].set()

    # -- sending -----------------------------------------------------------

    def _send(self, payload: dict) -> bool:
        sock = self._ensure_connected()
        if sock is None:
            return False
        data = (json.dumps(payload) + "\n").encode("utf-8")
        try:
            sock.sendall(data)
            return True
        except OSError:
            self._drop(sock)
            return False

    def say(self, text: str, mood: Optional[str] = None, seconds: float = 3.5) -> bool:
        """Shows `text` as the pet's speech bubble in Cariberry."""
        payload = {"type": "say", "text": text, "seconds": seconds}
        if mood:
            payload["mood"] = mood
        return self._send(payload)

    def transcribe(self, max_seconds: float = config.COMMAND_MAX_SECONDS, timeout: float = 20.0) -> str:
        """Asks Cariberry to record + transcribe the next utterance on-device.

        Blocks until Cariberry replies or `timeout` elapses. Returns "" if
        Cariberry isn't running, denied the mic, or heard nothing.
        """
        request_id = str(uuid.uuid4())
        event = threading.Event()
        self._pending[request_id] = event
        sent = self._send({"type": "transcribe", "id": request_id, "max_seconds": max_seconds})
        if not sent:
            del self._pending[request_id]
            return ""
        got_result = event.wait(timeout=timeout)
        text = self._results.pop(request_id, "")
        self._pending.pop(request_id, None)
        return text if got_result else ""
