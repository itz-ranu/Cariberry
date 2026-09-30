"""A small floating chat window for typed input, in Cariberry's warm/soft
visual language (cream background, rounded blush bubbles).

Runs its own Tk main loop on the main thread; `main.py` drives the
audio/brain/RPA side on background threads and calls back into this window
via `root.after(...)`, which is the only thread-safe way to touch Tk.
"""

from __future__ import annotations

import tkinter as tk
from tkinter import font as tkfont
from typing import Callable

BG = "#FFF8F0"           # warm cream, matches Cariberry's oat-milk palette
USER_BUBBLE = "#FDE7EC"  # soft blush
USER_TEXT = "#5A3E42"
CRANBERRY_BUBBLE = "#F2C9D2"  # a touch deeper pink for Cranberry's own lines
CRANBERRY_TEXT = "#5A2A34"
MUTED = "#B08A90"


def _rounded_rect(canvas: tk.Canvas, x1, y1, x2, y2, radius, **kwargs):
    points = [
        x1 + radius, y1, x2 - radius, y1, x2, y1, x2, y1 + radius,
        x2, y2 - radius, x2, y2, x2 - radius, y2, x1 + radius, y2,
        x1, y2, x1, y2 - radius, x1, y1 + radius, x1, y1,
    ]
    return canvas.create_polygon(points, smooth=True, **kwargs)


class ChatWindow:
    def __init__(self, on_send: Callable[[str], None], title: str = "Cranberry \U0001F43E"):
        self.on_send = on_send
        self.root = tk.Tk()
        self.root.title(title)

        width, height = 360, 480
        screen_w = self.root.winfo_screenwidth()
        x = max(20, screen_w - width - 40)
        y = 60
        self.root.geometry(f"{width}x{height}+{x}+{y}")
        self.root.configure(bg=BG)
        self.root.attributes("-topmost", True)

        self.text_font = tkfont.Font(family="Helvetica", size=13)
        self.hint_font = tkfont.Font(family="Helvetica", size=11, slant="italic")

        self._build_message_list()
        self._build_input_row()

        # A window opened by a background/automated process can otherwise end
        # up parked on whatever Space or window layer launched it, invisible
        # from the Space the person is actually looking at. Force it onto the
        # active Space and bring it to the front, on a short delay since Tk
        # only creates the underlying NSWindow once the event loop has run at
        # least once.
        self.root.after(50, self._force_to_foreground)
        self.root.after(400, self._force_to_foreground)
        self.root.after(1500, self._force_to_foreground)

    def _build_message_list(self) -> None:
        container = tk.Frame(self.root, bg=BG)
        container.pack(fill="both", expand=True, padx=8, pady=(8, 0))

        self.canvas = tk.Canvas(container, bg=BG, highlightthickness=0)
        scrollbar = tk.Scrollbar(container, orient="vertical", command=self.canvas.yview)
        self.canvas.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side="right", fill="y")
        self.canvas.pack(side="left", fill="both", expand=True)

        self.inner = tk.Frame(self.canvas, bg=BG)
        self._inner_window = self.canvas.create_window((0, 0), window=self.inner, anchor="nw")

        self.inner.bind("<Configure>", lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all")))
        self.canvas.bind("<Configure>", lambda e: self.canvas.itemconfig(self._inner_window, width=e.width))

    def _build_input_row(self) -> None:
        row = tk.Frame(self.root, bg=BG)
        row.pack(fill="x", padx=8, pady=8)

        self.entry = tk.Entry(row, font=self.text_font, relief="flat", bg="#FFFFFF", fg=USER_TEXT)
        self.entry.pack(side="left", fill="x", expand=True, ipady=8, padx=(0, 6))
        self.entry.bind("<Return>", lambda e: self._submit())
        self.entry.focus_set()

        send = tk.Button(
            row, text="Send", command=self._submit, relief="flat",
            bg=CRANBERRY_BUBBLE, fg=CRANBERRY_TEXT, activebackground=CRANBERRY_BUBBLE,
            font=self.text_font, padx=14,
        )
        send.pack(side="right")

    def _submit(self) -> None:
        text = self.entry.get().strip()
        if not text:
            return
        self.entry.delete(0, tk.END)
        self.add_message("you", text)
        self.on_send(text)

    def add_message(self, sender: str, text: str) -> None:
        """Thread-safe: schedules the bubble to be drawn on the Tk main thread."""
        self.root.after(0, self._add_message_now, sender, text)

    def set_status(self, text: str) -> None:
        self.root.after(0, self._set_status_now, text)

    def resize(self, factor: float) -> None:
        """Scales the window by `factor` (e.g. 1.15 to grow, 0.85 to shrink),
        anchored at its current top-left corner, clamped to a sane range."""
        self.root.after(0, self._resize_now, factor)

    def _resize_now(self, factor: float) -> None:
        width = max(280, min(700, int(self.root.winfo_width() * factor)))
        height = max(340, min(900, int(self.root.winfo_height() * factor)))
        x, y = self.root.winfo_x(), self.root.winfo_y()
        self.root.geometry(f"{width}x{height}+{x}+{y}")

    def _set_status_now(self, text: str) -> None:
        if hasattr(self, "_status_label"):
            self._status_label.destroy()
        self._status_label = tk.Label(self.inner, text=text, font=self.hint_font, bg=BG, fg=MUTED)
        self._status_label.pack(anchor="w", padx=6, pady=(0, 4))
        self._scroll_to_bottom()

    def _add_message_now(self, sender: str, text: str) -> None:
        is_user = sender == "you"
        bubble_color = USER_BUBBLE if is_user else CRANBERRY_BUBBLE
        text_color = USER_TEXT if is_user else CRANBERRY_TEXT
        anchor_side = "e" if is_user else "w"

        row = tk.Frame(self.inner, bg=BG)
        row.pack(fill="x", pady=4, padx=4)

        bubble = tk.Frame(row, bg=bubble_color)
        bubble.pack(side="right" if is_user else "left", anchor=anchor_side)

        label = tk.Label(
            bubble, text=text, font=self.text_font, bg=bubble_color, fg=text_color,
            wraplength=240, justify="left", padx=12, pady=8,
        )
        label.pack()

        self._scroll_to_bottom()

    def _scroll_to_bottom(self) -> None:
        self.canvas.update_idletasks()
        self.canvas.yview_moveto(1.0)

    def _force_to_foreground(self) -> None:
        """Activates this process and pulls its window onto whichever Space
        is currently active, instead of leaving it wherever the process
        happened to launch. Tk on macOS is itself Cocoa-backed, so this reaches
        into the same NSApplication Tk is already running -- not a second app."""
        try:
            from AppKit import NSApplication, NSWindowCollectionBehaviorMoveToActiveSpace
        except ImportError:
            return

        try:
            app = NSApplication.sharedApplication()
            app.activateIgnoringOtherApps_(True)
            # Bring every window this process owns forward, not just an exact
            # title match -- a plain Tk app only ever has the one real window,
            # so this is harmless, and a title match was silently finding
            # nothing on some launches for reasons still being tracked down.
            for window in app.windows():
                window.setCollectionBehavior_(NSWindowCollectionBehaviorMoveToActiveSpace)
                window.makeKeyAndOrderFront_(None)
        except Exception as exc:
            print(f"Cranberry: couldn't force the chat window to the foreground ({exc})")

    def run(self) -> None:
        self.root.mainloop()
