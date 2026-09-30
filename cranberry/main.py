"""Cranberry: run with `python -m cranberry.main` from the repo root.

Wires together everything else in this package:
  - the wake-word listener (audio/listen.py), if you've trained one
  - the brain (brain/infer.py) for understanding + replying
  - RPA actions (rpa/actions.py) for actually opening/closing apps
  - the bridge (bridge.py) to Cariberry.app, for speech bubbles + on-device STT
  - a text chat window (ui/chat_window.py) as the other input mode

Voice and text both end up in the same `handle_text()` path, so Cranberry
behaves identically either way.
"""

from __future__ import annotations

import threading

from . import config
from .bridge import CariberryBridge
from .brain.infer import Brain
from .ui.chat_window import ChatWindow

MOOD_BY_INTENT = {
    "open_app": "proud",
    "close_app": "proud",
    "greeting": "excited",
    "thanks": "love",
    "how_are_you": "happy",
    "small_talk": "curious",
}

# Resizing the chat window itself is a deterministic UI action tied to an
# object (this window) the brain has no concept of, so it's handled as a
# simple keyword check ahead of the brain entirely, the same way a GUI
# button click wouldn't need a learned classifier either.
_BIGGER_PHRASES = ("make it bigger", "make the window bigger", "bigger please", "size up", "zoom in", "make it larger")
_SMALLER_PHRASES = ("make it smaller", "make the window smaller", "smaller please", "size down", "zoom out", "shrink")


def _resize_factor(text: str) -> float | None:
    lowered = text.lower().strip()
    if lowered in ("bigger", "larger") or any(p in lowered for p in _BIGGER_PHRASES):
        return 1.15
    if lowered in ("smaller",) or any(p in lowered for p in _SMALLER_PHRASES):
        return 0.85
    return None


class Cranberry:
    def __init__(self) -> None:
        self.bridge = CariberryBridge()
        self.brain = Brain()
        self.chat: ChatWindow | None = None

        if not self.brain.is_trained:
            print(
                "Note: the brain hasn't been trained yet (falling back to keyword "
                "matching + canned replies). Run `python -m cranberry.brain.train` "
                "for real intent detection and generated small talk."
            )

    # -- shared handling for both voice and text input ----------------------

    def handle_text(self, text: str) -> None:
        resize = _resize_factor(text)
        if resize is not None:
            if self.chat:
                self.chat.resize(resize)
            reply = "sure thing! 🐾" if resize > 1 else "there we go 🐾"
            if self.chat:
                self.chat.add_message("cranberry", reply)
            self.bridge.say(reply, mood="proud", seconds=2.0)
            return

        result = self.brain.respond(text)
        mood = MOOD_BY_INTENT.get(result.intent)

        if self.chat:
            self.chat.add_message("cranberry", result.reply)
        self.bridge.say(result.reply, mood=mood, seconds=4.0)

        if result.intent == "open_app" and result.target_kind == "app" and result.app:
            self._run_task(f"🐾 opening {result.app}...", self._open_app, result.app)
        elif result.intent == "open_app" and result.target_kind == "url" and result.app:
            self._run_task("🐾 opening in your browser...", self._open_url, result.app)
        elif result.intent == "close_app" and result.target_kind == "app" and result.app:
            self._run_task(f"🐾 closing {result.app}...", self._close_app, result.app)
        elif result.intent == "close_app" and result.target_kind == "window":
            self._run_task("🐾 closing that window...", self._close_window)

    def _run_task(self, status: str, fn, *args) -> None:
        """Shows a small status line in the chat window while an RPA action
        runs in the background, so there's *something* visible happening for
        every task, not just the ones where the real cursor visibly moves."""
        if self.chat:
            self.chat.set_status(status)

        def worker() -> None:
            try:
                fn(*args)
            finally:
                if self.chat:
                    self.chat.set_status("")

        threading.Thread(target=worker, daemon=True).start()

    def _open_app(self, app_name: str) -> None:
        from .rpa import actions
        from .rpa.cursor_overlay import PawCursorOverlay

        try:
            overlay = PawCursorOverlay()
        except Exception as exc:  # pyobjc/AppKit issues shouldn't break the action
            print(f"Cranberry: couldn't create the paw overlay ({exc}); clicking without it.")
            overlay = None
        actions.open_app(app_name, overlay=overlay)

    def _open_url(self, url: str) -> None:
        from .rpa import actions
        actions.open_url(url)

    def _close_app(self, app_name: str) -> None:
        from .rpa import actions
        actions.close_app(app_name)

    def _close_window(self) -> None:
        from .rpa import actions
        actions.close_frontmost_window()

    # -- voice loop -----------------------------------------------------------

    def _run_wake_word_loop(self) -> None:
        from .audio.listen import WakeWordListener

        try:
            listener = WakeWordListener()
        except FileNotFoundError as exc:
            print(f"Cranberry: {exc}")
            print("Voice activation is off; the chat window still works.")
            return

        def on_wake() -> None:
            self.bridge.say("yes? \U0001F43E\U0001F442", mood="curious", seconds=2.0)
            if self.chat:
                self.chat.set_status("listening...")
            text = self.bridge.transcribe(max_seconds=config.COMMAND_MAX_SECONDS)
            if self.chat:
                self.chat.set_status("")
            if not text:
                self.bridge.say("hmm, didn't catch that \U0001F97A", seconds=2.5)
                return
            if self.chat:
                self.chat.add_message("you", text)
            self.handle_text(text)

        listener.listen_forever(on_wake)

    # -- entry point ------------------------------------------------------

    def run(self) -> None:
        print("Connecting to Cariberry...")
        if self.bridge.wait_for_cariberry(timeout=5.0):
            print("Connected.")
        else:
            print("Cariberry isn't running yet — Cranberry will keep retrying in the background.")

        threading.Thread(target=self._run_wake_word_loop, daemon=True).start()

        self.chat = ChatWindow(on_send=self.handle_text)
        self.chat.add_message("cranberry", "hi!! I'm listening for “Hey Cranberry” and I'm right here in chat too \U0001F43E")
        self.chat.run()


def main() -> None:
    Cranberry().run()


if __name__ == "__main__":
    main()
