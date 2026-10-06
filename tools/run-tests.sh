#!/bin/sh
# Run every Lua test against the Scripts folder it targets.
# Exits non-zero if any test fails; prints each failure's output.
cd "$(dirname "$0")/.." || exit 1
probe="src/Colors+Probe/Scripts"
scaffold="src/Colors+/Scripts" # bootstrap_test covers the Colors+ scaffold mod
pass=0
fail=0
for t in tests/*_test.lua; do
    dir=$probe
    [ "$(basename "$t")" = bootstrap_test.lua ] && dir=$scaffold
    if out=$(luajit "$t" "$dir" 2>&1); then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        printf 'FAIL %s\n%s\n\n' "$t" "$out" | head -25
    fi
done
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
