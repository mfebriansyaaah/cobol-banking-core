#!/usr/bin/env python3
"""Merge consecutive db_exec lines inside db_reset_*() bodies into one call.

Each db_exec spawns a mysql client (~34ms); ~500 reset helpers issue 2-6 of
them while every statement is a complete `DELETE ...;`. Joining preserves
order and exact SQL text. Functions whose body is not pure db_exec lines
(aliases delegating to another reset) and single-call bodies are left
byte-identical.

Usage: python3 scripts/merge_db_resets.py   (rewrites tests/lib/db.sh)
"""
import re

PATH = "tests/lib/db.sh"
FUNC_RE = re.compile(r"^db_reset_[a-z0-9_]+\(\) \{$")
EXEC_RE = re.compile(r'^(\s*)db_exec "(.*)"\s*$')

with open(PATH, encoding="utf-8") as f:
    lines = f.read().split("\n")

out = []
i = 0
merged_fns = 0
merged_calls = 0
touched = 0

while i < len(lines):
    if FUNC_RE.match(lines[i]):
        # Buffer the whole function body.
        body = []
        j = i + 1
        while j < len(lines) and lines[j] != "}":
            body.append(lines[j])
            j += 1
        if j < len(lines):
            close = lines[j]
            execs = [EXEC_RE.match(b) for b in body]
            if all(e is not None for e in execs) and len(execs) > 1:
                merged = " ".join(e.group(2) for e in execs)
                out.append(lines[i])
                out.append(f'    db_exec "{merged}"')
                out.append(close)
                merged_fns += 1
                merged_calls += len(execs) - 1
            else:
                out.append(lines[i])
                out.extend(body)
                out.append(close)
            touched += 1
            i = j + 1
            continue
    out.append(lines[i])
    i += 1

with open(PATH, "w", encoding="utf-8") as f:
    f.write("\n".join(out))

print(f"functions scanned: {touched}")
print(f"merged {merged_calls} db_exec calls into {merged_fns} functions")
