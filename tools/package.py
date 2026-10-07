"""Build the release ZIP from source, never the live mod directory.

src/ColorsPlus is the mod: the package is exactly its files. (A Dev package
with developer tools from src/Colors+Probe existed through 0.5.0.)
"""
from pathlib import Path
import hashlib
import json
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src" / "ColorsPlus"
SCRIPTS = SOURCE / "Scripts"
# Installed folder name (Colors_Probe through v0.3.0).
PACKAGE_ROOT = "ColorsPlus"
version = json.loads((SOURCE / "modinfo.json").read_text())["version"]
assert re.fullmatch(r"\d+\.\d+\.\d+", version), "Invalid package version"
assert json.loads((SOURCE / "zcom-mod.json").read_text())["version"] == version
assert f'local VERSION = "{version}"' in (SCRIPTS / "main.lua").read_text()
assert f"Colors+ v{version} " in (SOURCE / "README.md").read_text()

# Recovery/README.txt keeps the Recovery folder present after extraction:
# journals and session metadata are written there, and Lua cannot create it.
COMMON = [SOURCE / leaf for leaf in (
    "enabled.txt", "modinfo.json", "zcom-mod.json", "README.md", "Recovery/README.txt",
    "Assets/hue.png", "Assets/saturation.png", "Assets/value.png",
)]
REFERENCE = re.compile(r'module\("(\w+)"\)|"(\w+)\.lua"')


def references(path):
    return {m.group(1) or m.group(2) for m in REFERENCE.finditer(path.read_text())}


def player_scripts():
    """Every mod script, checked to be reachable from main.lua."""
    mod = {p.stem: p for p in SCRIPTS.glob("*.lua")}
    seen, pending = set(), ["main"]
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        for ref in references(mod[name]):
            assert ref in mod, f"{name}.lua needs missing script {ref}.lua"
            pending.append(ref)
    assert seen == mod.keys(), f"Unreachable mod scripts: {sorted(mod.keys() - seen)}"
    return sorted(mod.values())


def build(label, scripts):
    files = COMMON + scripts
    assert all(p.is_file() and not p.is_symlink() for p in files)
    entries = {f"{PACKAGE_ROOT}/" + p.relative_to(SOURCE).as_posix(): p for p in files}
    assert len(entries) == len(files)
    # Journals and session metadata (recovery_session.txt,
    # process_session_counter.txt), not scripts such as editor_session.lua.
    assert not any(re.search(r"_recovery\.txt|\.previous|\.archive-|session[^/]*\.txt$", name) for name in entries)
    output = ROOT / "dist" / ("-".join(["ColorsPlus"] + ([label] if label else []) + [version]) + ".zip")
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


build(None, player_scripts())  # ColorsPlus-<version>.zip (was -Testers- through 0.5.0)
