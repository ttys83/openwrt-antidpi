#!/usr/bin/env python3
"""Exercise patched BusyBox ash line editing through a real terminal."""

import os
import pty
import select
import sys
import tempfile
import time


def read_until_quiet(fd, timeout=4):
    chunks = bytearray()
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], 0.15)
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            chunks.extend(data)
            deadline = time.monotonic() + 0.3
        elif chunks:
            break
    return bytes(chunks)


def send(fd, command, expected):
    os.write(fd, command)
    output = read_until_quiet(fd)
    needle = ("\r\n" + expected + "\r\n").encode()
    if needle not in output:
        raise AssertionError(f"Expected {expected!r}; got {output!r}")


with tempfile.TemporaryDirectory() as home:
    pid, fd = pty.fork()
    if pid == 0:
        os.environ.clear()
        os.environ.update(HOME=home, TERM="vt100", PS1="PROMPT> ", LANG="C.UTF-8")
        os.execv(sys.argv[1], [sys.argv[1], "ash", "-i"])

    try:
        read_until_quiet(fd)
        send(fd, b"echo ip-one\r", "ip-one")
        send(fd, b"echo other\r", "other")
        send(fd, b"echo ip-two\r", "ip-two")
        send(fd, b"echo ip\x1b[A\r", "ip-two")
        send(fd, b"echo ip\x1b[A\x1b[A\r", "ip-one")
        send(fd, b"echo ip\x1b[A\x1b[A\x1b[B\x1b[B-new\r", "ip-new")
        send(fd, b"\x1b[A\r", "ip-new")
        send(fd, "echo кот".encode() + b"\x7f" + "д".encode() + b"\r", "код")
        print("PTY checks passed: prefix up/down, empty up, Cyrillic Backspace")
    finally:
        os.write(fd, b"exit\r")
        os.waitpid(pid, 0)
