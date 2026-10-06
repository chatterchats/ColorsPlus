#!/bin/sh
# Run every Lua test against the Dev package layout: src/ColorsPlus with the
# developer scripts from src/Colors+Probe/Scripts linked into its Scripts
# folder (as tools/package-testers.py builds it). The packager separately
# checks that src/ColorsPlus alone needs no developer script.
# Usage: tools/run-tests.sh [test_name ...]   (default: every tests/*_test.lua)
# Exits non-zero if any test fails; prints each failure's output.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
tree=$(mktemp -d) || exit 1
trap 'rm -rf "$tree"' EXIT
mkdir "$tree/Scripts"
for f in src/ColorsPlus/Scripts/*.lua src/Colors+Probe/Scripts/*.lua; do
    name=$(basename "$f")
    if [ -e "$tree/Scripts/$name" ]; then echo "Script in both trees: $name"; exit 1; fi
    ln -s "$root/$f" "$tree/Scripts/$name"
done
ln -s "$root/src/ColorsPlus/DevPanel" "$tree/DevPanel"
ln -s "$root/src/ColorsPlus/Assets" "$tree/Assets"
pass=0
fail=0
if [ $# -gt 0 ]; then
    tests=""; for n in "$@"; do tests="$tests tests/${n%_test}_test.lua"; done
else
    tests=$(ls tests/*_test.lua)
fi
for t in $tests; do
    if out=$(luajit "$t" "$tree/Scripts" 2>&1); then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        printf 'FAIL %s\n%s\n\n' "$t" "$out" | head -25
    fi
done
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
