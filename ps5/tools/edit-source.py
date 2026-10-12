#!/usr/bin/env python3
"""DevilutionX for the PlayStation 5 - replace text in an upstream file, keeping its line endings.

    edit-source.py FILE < edits      (edits: Python literal, a list of (old, new) pairs)

Upstream's sources end their lines with CR LF; an editor that rewrites them
turns a five-line change into the whole file. SPDX-License-Identifier: MIT
"""
import ast
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_bytes().decode()
crlf = "\r\n" in text
text = text.replace("\r\n", "\n")
for old, new in ast.literal_eval(sys.stdin.read()):
    if text.count(old) != 1:
        sys.exit(f"{path}: the text to replace occurs {text.count(old)} times: {old[:60]!r}")
    text = text.replace(old, new)
path.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode())
