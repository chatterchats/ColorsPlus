"""Build clean player and dev ZIPs from an allowlist, never the live mod directory.

Player package: the scripts reachable from main.lua without dev_tools.lua
(picker, editing backend, recovery, automatic performance log).
Dev package: every script, including probes, traces and Dev Panel integration.
"""
from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src" / "Colors+Probe"
SCRIPTS = SOURCE / "Scripts"
version = json.loads((SOURCE / "modinfo.json").read_text())["version"]
assert re.fullmatch(r"\d+\.\d+\.\d+", version), "Invalid package version"
assert json.loads((SOURCE / "zcom-mod.json").read_text())["version"] == version
assert f'local VERSION = "{version}"' in (SCRIPTS / "main.lua").read_text()
assert f'version = "{version}"' in (SOURCE / "DevPanel/actions.lua").read_text()
assert f"v{version}" in (SOURCE / "TESTING.md").read_text()

# DevPanel/actions.lua ships in both packages: the DevPanel folder must exist
# because recovery journals and session metadata are written there.
COMMON = [SOURCE / leaf for leaf in (
    "enabled.txt", "modinfo.json", "zcom-mod.json", "TESTING.md", "DevPanel/actions.lua",
    "Assets/hue.png", "Assets/saturation.png", "Assets/value.png",
)]
DEV_ENTRY = "dev_tools"
REFERENCE = re.compile(r'module\("(\w+)"\)|"(\w+)\.lua"')


def player_scripts():
    """Scripts transitively referenced from main.lua, never entering dev_tools."""
    available = {p.stem for p in SCRIPTS.glob("*.lua")}
    seen, pending = set(), ["main"]
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        text = (SCRIPTS / f"{name}.lua").read_text()
        for match in REFERENCE.finditer(text):
            ref = match.group(1) or match.group(2)
            if ref == DEV_ENTRY or ref not in available:
                continue
            pending.append(ref)
    return sorted(SCRIPTS / f"{name}.lua" for name in seen)


def build(label, scripts):
    files = COMMON + scripts
    assert all(p.is_file() and not p.is_symlink() for p in files)
    entries = {"Colors_Probe/" + p.relative_to(SOURCE).as_posix(): p for p in files}
    assert len(entries) == len(files)
    assert not any("recovery" in name and not name.endswith(".lua") for name in entries)
    output = ROOT / "dist" / f"ColorsPlus-{label}-{version}.zip"
    output.parent.mkdir(exist_ok=True)
    if output.exists():
        # A released version is immutable: same version, same bytes, or bump it.
        with zipfile.ZipFile(output) as existing:
            same = set(existing.namelist()) == set(entries) and all(
                existing.read(name) == source.read_bytes() for name, source in entries.items())
        assert same, f"{output.name} already exists with different contents; bump the version"
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
    print(f"Verified {len(entries)} packaged files ({len(scripts)} scripts): {output}")
    print(f"SHA256: {digest}")


player = player_scripts()
assert SCRIPTS / f"{DEV_ENTRY}.lua" not in player, "Player package must not contain dev tools"
everything = sorted(SCRIPTS.glob("*.lua"))
build("Testers", player)
build("Dev", everything)
print("Dev-only scripts: " + ", ".join(p.stem for p in everything if p not in player))
