#!/usr/bin/env python3
"""Streams the Hyprland cursor position as "x y" lines while the pet is in chase mode.

Wayland doesn't give clients the global pointer, so this asks Hyprland's request socket
(the same one hyprctl uses). It only runs while chase mode is on.
"""
import json
import os
import socket
import sys
import time


def main():
    interval = float(sys.argv[1]) if len(sys.argv) > 1 else 0.033
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    path = os.path.join(runtime, "hypr", sig, ".socket.sock")
    parent = os.getppid()
    last = None
    while True:
        if os.getppid() != parent:
            return
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(0.5)
                s.connect(path)
                s.sendall(b"j/cursorpos")
                chunks = []
                while True:
                    chunk = s.recv(4096)
                    if not chunk:
                        break
                    chunks.append(chunk)
            data = json.loads(b"".join(chunks).decode("utf-8", "replace"))
            cur = (int(data["x"]), int(data["y"]))
            if cur != last:
                sys.stdout.write(f"{cur[0]} {cur[1]}\n")
                sys.stdout.flush()
                last = cur
        except BrokenPipeError:
            return
        except Exception:
            time.sleep(0.25)
        time.sleep(interval)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
