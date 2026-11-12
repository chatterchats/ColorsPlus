"""Every shipped script is loaded from main.lua, and every script it loads exists.

Run from the repo root: make test T=scripts_reachable_test
"""
import re
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1] / "src" / "ColorsPlus" / "Scripts"
REFERENCE = re.compile(r'module\("(\w+)"\)|"(\w+)\.lua"')


class ScriptsReachable(unittest.TestCase):
    def test_every_script_is_reachable_from_main(self):
        mod = {path.stem: path for path in SCRIPTS.glob("*.lua")}
        seen, pending = set(), ["main"]
        while pending:
            name = pending.pop()
            if name in seen:
                continue
            seen.add(name)
            for match in REFERENCE.finditer(mod[name].read_text()):
                ref = match.group(1) or match.group(2)
                self.assertIn(ref, mod, f"{name}.lua needs missing script {ref}.lua")
                pending.append(ref)
        self.assertEqual(sorted(mod.keys() - seen), [], "unreachable scripts")


if __name__ == "__main__":
    unittest.main()
