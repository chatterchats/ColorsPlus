"""Build a clean tester ZIP from an allowlist, never the live mod directory."""
from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src" / "Colors+Probe"
version = json.loads((SOURCE / "modinfo.json").read_text())["version"]
assert re.fullmatch(r"\d+\.\d+\.\d+", version), "Invalid package version"
assert json.loads((SOURCE / "zcom-mod.json").read_text())["version"] == version
assert f'local VERSION = "{version}"' in (SOURCE / "Scripts/main.lua").read_text()
assert f'version = "{version}"' in (SOURCE / "DevPanel/actions.lua").read_text()
assert f"v{version}" in (SOURCE / "TESTING.md").read_text()

files = [SOURCE / leaf for leaf in (
    "enabled.txt", "modinfo.json", "zcom-mod.json", "TESTING.md", "DevPanel/actions.lua",
    "Assets/hue.png", "Assets/saturation.png", "Assets/value.png",
)] + sorted((SOURCE / "Scripts").glob("*.lua"))
assert all(p.is_file() and not p.is_symlink() for p in files)
entries = {"Colors_Probe/" + p.relative_to(SOURCE).as_posix(): p for p in files}
assert len(entries) == len(files)
assert not any("recovery" in name and not name.endswith(".lua") for name in entries)

output = ROOT / "dist" / f"ColorsPlus-Testers-{version}.zip"
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for name, source in entries.items():
        archive.write(source, name)
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == set(entries)
    for name, source in entries.items():
        assert archive.read(name) == source.read_bytes(), name
digest = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix(".zip.sha256").write_text(f"{digest}  {output.name}\n")
print(f"Verified {len(entries)} packaged files: {output}")
print(f"SHA256: {digest}")
