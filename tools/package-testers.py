"""Build clean player and dev ZIPs from source, never the live mod directory.

src/ColorsPlus is the mod: the Testers package is exactly its files.
src/Colors+Probe/Scripts holds developer tools (traces, the compatibility
survey, console commands). The Dev package overlays them into the same Scripts folder:
UE4SS gives every mod its own Lua state, so the tools must run inside the mod.
"""
from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src" / "ColorsPlus"
SCRIPTS = SOURCE / "Scripts"
DEV_SCRIPTS = ROOT / "src" / "Colors+Probe" / "Scripts"
# Installed folder name; the rename to ColorsPlus is planned for v0.4.
PACKAGE_ROOT = "Colors_Probe"
version = json.loads((SOURCE / "modinfo.json").read_text())["version"]
assert re.fullmatch(r"\d+\.\d+\.\d+", version), "Invalid package version"
assert json.loads((SOURCE / "zcom-mod.json").read_text())["version"] == version
assert f'local VERSION = "{version}"' in (SCRIPTS / "main.lua").read_text()
assert f"v{version}" in (SOURCE / "TESTING.md").read_text()

# Recovery/README.txt keeps the Recovery folder present after extraction:
# journals and session metadata are written there, and Lua cannot create it.
COMMON = [SOURCE / leaf for leaf in (
    "enabled.txt", "modinfo.json", "zcom-mod.json", "TESTING.md", "Recovery/README.txt",
    "Assets/hue.png", "Assets/saturation.png", "Assets/value.png",
)]
DEV_ENTRY = "dev_tools"
REFERENCE = re.compile(r'module\("(\w+)"\)|"(\w+)\.lua"')


def references(path):
    return {m.group(1) or m.group(2) for m in REFERENCE.finditer(path.read_text())}


def player_scripts():
    """Every mod script, checked to be reachable from main.lua and to need no
    developer script (main.lua loads dev_tools.lua only when present)."""
    mod = {p.stem: p for p in SCRIPTS.glob("*.lua")}
    dev = {p.stem for p in DEV_SCRIPTS.glob("*.lua")}
    assert not mod.keys() & dev, f"Script in both trees: {sorted(mod.keys() & dev)}"
    assert DEV_ENTRY in dev
    seen, pending = set(), ["main"]
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        for ref in references(mod[name]):
            if ref == DEV_ENTRY or ref not in mod and ref not in dev:
                continue
            assert ref in mod, f"{name}.lua needs developer script {ref}.lua"
            pending.append(ref)
    assert seen == mod.keys(), f"Unreachable mod scripts: {sorted(mod.keys() - seen)}"
    return sorted(mod.values())


def dev_scripts():
    return sorted(DEV_SCRIPTS.glob("*.lua"))


def build(label, scripts):
    files = COMMON + scripts
    assert all(p.is_file() and not p.is_symlink() for p in files)
    entries = {f"{PACKAGE_ROOT}/" + (p.relative_to(SOURCE).as_posix() if p.is_relative_to(SOURCE)
               else "Scripts/" + p.name): p for p in files}
    assert len(entries) == len(files)
    assert not any(re.search(r"_recovery\.txt|\.previous|\.archive-|session", name) for name in entries)
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
build("Testers", player)
build("Dev", player + dev_scripts())
print("Dev-only scripts: " + ", ".join(p.stem for p in dev_scripts()))
