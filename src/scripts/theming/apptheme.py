#!/usr/bin/env python3
import argparse
import fcntl
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ID_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
CATEGORIES = ("system", "terminals", "editors", "tools", "apps")
MARK_BEGIN = ">>> serpantinum theme >>>"
MARK_END = "<<< serpantinum theme <<<"
MARK_DISABLED = "serpantinum-disabled: "
HEADER_RE = re.compile(r"^\[(.*)\]\s*(?:[#;].*)?$")
STATE_VERSION = 1
MATUGEN_TIMEOUT = 60
EXTRA_BIN_DIRS = (
    "~/.local/bin",
    "~/.nix-profile/bin",
    "~/.cargo/bin",
    "/run/current-system/sw/bin",
    "/etc/profiles/per-user/{user}/bin",
    "/var/lib/flatpak/exports/bin",
    "~/.local/share/flatpak/exports/bin",
    "/usr/local/bin",
    "/usr/bin",
    "/bin",
    "/snap/bin",
)


class AppError(Exception):
    pass


def _xdg(name, fallback):
    value = os.environ.get(name, "")
    return Path(value) if value and os.path.isabs(value) else Path.home() / fallback


class Context:
    def __init__(self):
        self.home = Path.home()
        self.config_home = _xdg("XDG_CONFIG_HOME", ".config")
        self.data_home = _xdg("XDG_DATA_HOME", ".local/share")
        self.cache_home = _xdg("XDG_CACHE_HOME", ".cache")
        self.state_home = _xdg("XDG_STATE_HOME", ".local/state")
        qs_state = os.environ.get("QS_STATE_DIR", "")
        self.state_dir = Path(qs_state) if qs_state and os.path.isabs(qs_state) else self.state_home / "serpantinum"
        self.work = self.state_dir / "matugen"
        self.palette = self.work / "palette.json"
        self.state_file = self.work / "apps-state.json"
        settings = os.environ.get("QS_SETTINGS", "")
        self.settings = Path(settings) if settings and os.path.isabs(settings) else self.config_home / "serpantinum" / "settings.json"
        builtin = os.environ.get("SERPANTINUM_APPTHEME_BUILTIN", "")
        self.builtin_dir = Path(builtin) if builtin else Path(__file__).resolve().parent.parent.parent / "assets" / "matugen" / "apps"
        self.user_dir = self.config_home / "serpantinum" / "matugen" / "apps"
        self.matugen = os.environ.get("SERPANTINUM_MATUGEN", "matugen")
        data_dirs = os.environ.get("XDG_DATA_DIRS", "") or "/usr/local/share:/usr/share"
        self.data_dirs = [Path(p) for p in data_dirs.split(":") if p and os.path.isabs(p)]
        config_dirs = os.environ.get("XDG_CONFIG_DIRS", "") or "/etc/xdg"
        self.config_dirs = [Path(p) for p in config_dirs.split(":") if p and os.path.isabs(p)]

    def tilde(self, path):
        path = Path(path)
        try:
            return "~/" + str(path.relative_to(self.home))
        except ValueError:
            return str(path)

    def variables(self, mode):
        return {
            "XDG_CONFIG_HOME": str(self.config_home),
            "XDG_DATA_HOME": str(self.data_home),
            "XDG_CACHE_HOME": str(self.cache_home),
            "XDG_STATE_HOME": str(self.state_home),
            "HOME": str(self.home),
            "TILDE_CONFIG_HOME": self.tilde(self.config_home),
            "TILDE_DATA_HOME": self.tilde(self.data_home),
            "TILDE_CACHE_HOME": self.tilde(self.cache_home),
            "MODE": mode,
        }

    def expand(self, value, mode="dark"):
        if not isinstance(value, str):
            raise AppError("expected a string")
        variables = self.variables(mode)

        def repl(match):
            name = match.group(1) or match.group(2)
            if name not in variables:
                raise AppError("unknown variable $" + name)
            return variables[name]

        out = re.sub(r"\$\{([A-Z_]+)\}|\$([A-Z_]+)", repl, value)
        if out == "~" or out.startswith("~/"):
            out = str(self.home) + out[1:]
        return out

    def expand_path(self, value, mode="dark"):
        out = self.expand(value, mode)
        if not os.path.isabs(out):
            raise AppError("path must be absolute: " + value)
        return Path(os.path.normpath(out))


def read_json(path, default):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return default


def sha(data):
    return hashlib.sha256(data).hexdigest()


def file_hash(path):
    try:
        with open(path, "rb") as handle:
            return sha(handle.read())
    except OSError:
        return None


def atomic_write(path, data, follow_symlink=False):
    path = Path(path)
    if follow_symlink and path.is_symlink():
        path = Path(os.path.realpath(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = None
    try:
        mode = os.stat(path).st_mode & 0o7777
    except OSError:
        pass
    fd, tmp = tempfile.mkstemp(prefix="." + path.name + ".", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        if mode is not None:
            os.chmod(tmp, mode)
        else:
            os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def search_path():
    dirs = [d for d in os.environ.get("PATH", "").split(":") if d]
    user = os.environ.get("USER", "")
    for extra in EXTRA_BIN_DIRS:
        dirs.append(os.path.expanduser(extra.replace("{user}", user)))
    seen, out = set(), []
    for d in dirs:
        if d not in seen:
            seen.add(d)
            out.append(d)
    return os.pathsep.join(out)


_PATH_CACHE = {}


def which(name):
    if name not in _PATH_CACHE:
        _PATH_CACHE[name] = shutil.which(name, path=search_path())
    return _PATH_CACHE[name]


_VERSION_CACHE = {}


def parse_version(text):
    m = re.search(r"(\d+)\.(\d+)(?:\.(\d+))?", text or "")
    return tuple(int(x or 0) for x in m.groups()) if m else None


def version_ok(spec):
    binary = which(spec.get("bin", ""))
    if not binary:
        return False
    key = (binary, tuple(spec.get("args", ["--version"])))
    if key not in _VERSION_CACHE:
        try:
            proc = subprocess.run([binary] + list(key[1]), capture_output=True, text=True, timeout=5)
            _VERSION_CACHE[key] = parse_version(proc.stdout + proc.stderr)
        except (OSError, subprocess.SubprocessError):
            _VERSION_CACHE[key] = None
    found = _VERSION_CACHE[key]
    if found is None:
        return spec.get("unknown", False)
    if spec.get("min") and found < parse_version(spec["min"]):
        return False
    if spec.get("below") and found >= parse_version(spec["below"]):
        return False
    return True


def check_when(ctx, cond, mode="dark"):
    if not cond:
        return True
    if "version" in cond and not version_ok(cond["version"]):
        return False
    if not any(cond.get(k) for k in ("bin", "flatpak", "path")):
        return True
    for name in cond.get("bin", []):
        if which(name):
            return True
    for app_id in cond.get("flatpak", []):
        for base in [Path("/var/lib/flatpak/app"), ctx.data_home / "flatpak" / "app"]:
            if (base / app_id).is_dir():
                return True
    for raw in cond.get("path", []):
        if ctx.expand_path(raw, mode).exists():
            return True
    return False


def as_list(value):
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def json_walk(data, keys):
    if not keys:
        yield data
        return
    head, rest = keys[0], keys[1:]
    if head == "*":
        children = data.values() if isinstance(data, dict) else data if isinstance(data, list) else []
        for child in children:
            yield from json_walk(child, rest)
    elif isinstance(data, dict) and head in data:
        yield from json_walk(data[head], rest)


def each_dirs(ctx, spec, mode):
    found = []
    for source in as_list(spec.get("each")):
        if isinstance(source, str):
            for match in sorted(glob.glob(str(ctx.expand_path(source, mode)))):
                found.append(os.path.dirname(match))
        elif isinstance(source, dict):
            data = read_json(ctx.expand_path(source["json"], mode), None)
            for value in json_walk(data, source.get("key", "").split(".")):
                if isinstance(value, str) and os.path.isabs(value) and os.path.isdir(value):
                    found.append(os.path.normpath(value))
    return list(dict.fromkeys(found))


def substitute(value, each):
    if isinstance(value, str):
        return value.replace("${EACH}", each).replace("$EACH", each)
    if isinstance(value, list):
        return [substitute(v, each) for v in value]
    if isinstance(value, dict):
        return {k: substitute(v, each) for k, v in value.items()}
    return value


def concrete(ctx, specs, mode):
    out = []
    for spec in specs:
        if not spec.get("each"):
            out.append(spec)
            continue
        rest = {k: v for k, v in spec.items() if k != "each"}
        out.extend(substitute(rest, d) for d in each_dirs(ctx, spec, mode))
    return out


def validate_app(app_id, data, directory):
    if not ID_RE.match(app_id):
        raise AppError("invalid id")
    if not isinstance(data, dict):
        raise AppError("app.json must be an object")
    if not isinstance(data.get("name"), str) or not data["name"].strip():
        raise AppError("missing name")
    templates = data.get("templates", [])
    if not isinstance(templates, list) or not templates:
        raise AppError("templates must be a non-empty list")
    for tpl in templates:
        if not isinstance(tpl, dict) or not isinstance(tpl.get("input"), str) or not isinstance(tpl.get("output"), str):
            raise AppError("each template needs input and output")
        source = (directory / tpl["input"]).resolve()
        if directory.resolve() not in source.parents:
            raise AppError("template input must stay inside the app folder")
        if not source.is_file():
            raise AppError("missing template file " + tpl["input"])
    for spec in data.get("integrate", []):
        if not isinstance(spec, dict) or spec.get("type") not in ("line", "ini", "gsettings", "json"):
            raise AppError("unknown integration type")
        if spec["type"] == "line" and not as_list(spec.get("line")) and not spec.get("lines_from"):
            raise AppError("line integration needs line")
        if spec["type"] == "json" and not any(spec.get(k) for k in ("values", "values_from", "values_by_mode", "append")):
            raise AppError("json integration needs values")
        if spec["type"] in ("line", "ini", "json") and not as_list(spec.get("file")):
            raise AppError("integration needs file")
        for source in as_list(spec.get("each")):
            if not isinstance(source, str) and not (isinstance(source, dict) and isinstance(source.get("json"), str)):
                raise AppError("each entries must be globs or json sources")
        for key in ("disable", "skip_if"):
            if spec.get(key):
                re.compile(spec[key])
        position = spec.get("position")
        if isinstance(position, dict):
            re.compile(position.get("before", ""))
    for item in as_list(data.get("reload")):
        if not isinstance(item, str):
            raise AppError("reload entries must be strings")


class App:
    def __init__(self, app_id, directory, data, builtin, custom, error=None):
        self.id = app_id
        self.dir = directory
        self.data = data or {}
        self.builtin = builtin
        self.custom = custom
        self.error = error

    @property
    def name(self):
        return self.data.get("name") or self.id

    def raw_bytes(self):
        hasher = hashlib.sha256()
        hasher.update(json.dumps(self.data, sort_keys=True).encode())
        for tpl in self.data.get("templates", []):
            hasher.update(tpl["input"].encode())
            try:
                hasher.update((self.dir / tpl["input"]).read_bytes())
            except OSError:
                pass
        return hasher.hexdigest()


def load_one(app_id, directory, builtin, custom):
    try:
        data = read_json(directory / "app.json", None)
        if data is None:
            raise AppError("app.json is missing or not valid JSON")
        validate_app(app_id, data, directory)
        return App(app_id, directory, data, builtin, custom)
    except (AppError, re.error) as exc:
        return App(app_id, directory, data if isinstance(data, dict) else {}, builtin, custom, str(exc))


def load_apps(ctx):
    apps = {}
    builtin_ids = set()
    if ctx.builtin_dir.is_dir():
        for entry in sorted(ctx.builtin_dir.iterdir()):
            if entry.is_dir() and ID_RE.match(entry.name):
                builtin_ids.add(entry.name)
                apps[entry.name] = load_one(entry.name, entry, True, False)
    if ctx.user_dir.is_dir():
        for entry in sorted(ctx.user_dir.iterdir()):
            if entry.name in builtin_ids and entry.is_dir() and (entry / "app.json").is_file():
                apps[entry.name] = load_one(entry.name, entry, True, True)
    return apps


def installed(ctx, app):
    detect = app.data.get("detect")
    if not detect:
        return True
    try:
        return check_when(ctx, detect)
    except AppError:
        return False


def enabled_ids(ctx, apps, override=None):
    if override is not None:
        return {i for i in override if i}
    settings = read_json(ctx.settings, {})
    theme = settings.get("theme") if isinstance(settings, dict) else None
    chosen = theme.get("apps") if isinstance(theme, dict) else None
    if isinstance(chosen, list):
        return {i for i in chosen if isinstance(i, str)}
    return {a.id for a in apps.values() if a.data.get("default") is True and a.builtin}


def load_state(ctx):
    state = read_json(ctx.state_file, {})
    if not isinstance(state, dict) or state.get("version") != STATE_VERSION:
        state = {"version": STATE_VERSION}
    state.setdefault("applied", {})
    state.setdefault("results", {})
    return state


def save_state(ctx, state):
    atomic_write(ctx.state_file, (json.dumps(state, indent=2, sort_keys=True) + "\n").encode())


def split_lines(text):
    lines = text.split("\n")
    trailing = len(lines) > 1 and lines[-1] == ""
    if trailing:
        lines.pop()
    if lines == [""]:
        lines = []
    return lines, trailing


def join_lines(lines, trailing=True):
    if not lines:
        return ""
    return "\n".join(lines) + ("\n" if trailing else "")


def comment_pair(spec):
    style = spec.get("comment", "#")
    if isinstance(style, list):
        return style[0], (" " + style[1]) if len(style) > 1 and style[1] else ""
    return style, ""


def disabled_regex(pre, post):
    return re.compile(r"^(\s*)" + re.escape(pre) + " " + re.escape(MARK_DISABLED) + r"(.*?)" + re.escape(post) + r"$")


def strip_blocks(lines):
    out, first = [], None
    i = 0
    while i < len(lines):
        if MARK_BEGIN in lines[i]:
            j = i + 1
            while j < len(lines) and MARK_END not in lines[j]:
                j += 1
            if j >= len(lines):
                out.append(lines[i])
                i += 1
                continue
            if first is None:
                first = len(out)
            i = j + 1
            continue
        out.append(lines[i])
        i += 1
    return out, first


def section_range(lines, section):
    if section is None:
        return 0, len(lines)
    headers = [(i, m.group(1).strip()) for i, line in enumerate(lines) for m in [HEADER_RE.match(line)] if m]
    if section == "":
        return 0, headers[0][0] if headers else len(lines)
    for idx, (i, name) in enumerate(headers):
        if name == section:
            end = headers[idx + 1][0] if idx + 1 < len(headers) else len(lines)
            return i + 1, end
    return None


def resolve_file(ctx, spec, mode):
    candidates = [ctx.expand_path(p, mode) for p in as_list(spec.get("file"))]
    for path in candidates:
        if path.exists():
            return path, True
    create = spec.get("create_at")
    return (ctx.expand_path(create, mode) if create else candidates[0]), False


def hidden_by_system(ctx, path):
    try:
        rel = path.relative_to(ctx.config_home)
    except ValueError:
        return None
    for base in ctx.config_dirs:
        if (base / rel).is_file():
            return base / rel
    return None


def writable_target(path):
    real = Path(os.path.realpath(path))
    if real.exists():
        return os.access(real, os.W_OK) and os.access(real.parent, os.W_OK)
    parent = real.parent
    while not parent.exists() and parent != parent.parent:
        parent = parent.parent
    return os.access(parent, os.W_OK)


def read_text(path):
    with open(path, "r", encoding="utf-8", errors="surrogateescape", newline="") as handle:
        return handle.read()


def write_text(path, text):
    atomic_write(path, text.encode("utf-8", errors="surrogateescape"), follow_symlink=True)


def apply_line(ctx, spec, mode, record):
    pre, post = comment_pair(spec)
    want = [ctx.expand(l, mode) for l in as_list(spec.get("line"))]
    if spec.get("lines_from"):
        source = ctx.expand_path(spec["lines_from"], mode)
        try:
            want += read_text(source).replace("\r\n", "\n").rstrip("\n").split("\n")
        except OSError:
            raise AppError("missing " + ctx.tilde(source))
    path, exists = resolve_file(ctx, spec, mode)
    hint = {"file": str(path), "line": "\n".join(want)}
    if not exists:
        if not spec.get("create", False):
            return False, dict(hint, code="missing_config")
        hidden = hidden_by_system(ctx, path)
        if hidden:
            return False, dict(hint, code="system_config", file=str(hidden))
    if not writable_target(path):
        return False, dict(hint, code="read_only")
    original = read_text(path) if exists else ""
    crlf = "\r\n" in original
    lines, trailing = split_lines(original.replace("\r\n", "\n"))
    lines, block_at = strip_blocks(lines)
    disabled_re = disabled_regex(pre, post)
    section = spec.get("section")
    scope = section_range(lines, section)
    issue = None
    insert = True
    if scope is not None:
        active = [i for i in range(scope[0], scope[1]) if not disabled_re.match(lines[i])]
        skip_re = re.compile(spec["skip_if"]) if spec.get("skip_if") else None
        if skip_re and any(skip_re.search(lines[i]) for i in active):
            issue = dict(hint, code="manual")
            insert = False
        elif all(any(lines[i].strip() == w.strip() for i in active) for w in want):
            insert = False
    insert_at = None
    pad = False
    if insert:
        if block_at is not None and (scope is None or scope[0] <= block_at <= scope[1]):
            insert_at = block_at
        elif scope is None:
            insert_at = len(lines)
            pad = True
        elif isinstance(spec.get("position"), dict):
            before = re.compile(spec["position"]["before"])
            insert_at = next((i for i in range(scope[0], scope[1]) if before.search(lines[i])), None)
            if insert_at is None:
                issue = dict(hint, code="manual")
                insert = False
        elif spec.get("position") == "start" or (section is not None and spec.get("position") != "end"):
            insert_at = scope[0]
        else:
            insert_at = scope[1]
            while insert_at > scope[0] and not lines[insert_at - 1].strip():
                insert_at -= 1
            pad = True
    if insert:
        if spec.get("disable"):
            disable_re = re.compile(spec["disable"])
            for i in range(scope[0], scope[1]) if scope is not None else []:
                line = lines[i]
                if disabled_re.match(line) or not disable_re.search(line):
                    continue
                if any(line.strip() == w.strip() for w in want):
                    continue
                indent = line[: len(line) - len(line.lstrip())]
                lines[i] = indent + pre + " " + MARK_DISABLED + line.lstrip() + post
        body = want
        if scope is None:
            body = ["[" + section + "]"] + want
        block = [pre + " " + MARK_BEGIN + post] + body + [pre + " " + MARK_END + post]
        if pad and insert_at > 0 and lines[insert_at - 1].strip():
            block = [""] + block
            padded = record.setdefault("padded", [])
            if str(path) not in padded:
                padded.append(str(path))
        lines[insert_at:insert_at] = block
        trailing = True
    else:
        for i, line in enumerate(lines):
            m = disabled_re.match(line)
            if m:
                lines[i] = m.group(1) + m.group(2)
    new_text = join_lines(lines, trailing)
    if crlf:
        new_text = new_text.replace("\n", "\r\n")
    record.setdefault("lines", {})[str(path)] = spec.get("comment", "#")
    if insert and exists and original and not original.endswith("\n") and block_at is None:
        no_eol = record.setdefault("no_eol", [])
        if str(path) not in no_eol:
            no_eol.append(str(path))
    if not exists and insert:
        record.setdefault("created", [])
        if str(path) not in record["created"]:
            record["created"].append(str(path))
    if new_text != original:
        write_text(path, new_text)
        return True, issue
    return False, issue


def restore_eol(text, no_eol):
    if no_eol and text.endswith("\r\n"):
        return text[:-2]
    if no_eol and text.endswith("\n"):
        return text[:-1]
    return text


def undo_line(comment, path, created=False, no_eol=False, padded=False):
    pre, post = comment_pair({"comment": comment})
    path = Path(path)
    if not path.exists() or not writable_target(path):
        return False
    original = read_text(path)
    lines, trailing = split_lines(original.replace("\r\n", "\n"))
    lines, block_at = strip_blocks(lines)
    disabled_re = disabled_regex(pre, post)
    for i, line in enumerate(lines):
        m = disabled_re.match(line)
        if m:
            lines[i] = m.group(1) + m.group(2)
    if block_at is not None and 0 < block_at <= len(lines) and not lines[block_at - 1].strip():
        if padded or block_at == len(lines) or not lines[block_at].strip():
            del lines[block_at - 1]
    new_text = join_lines(lines, trailing)
    if "\r\n" in original:
        new_text = new_text.replace("\n", "\r\n")
    new_text = restore_eol(new_text, no_eol)
    if created and not new_text.strip():
        path.unlink()
        return True
    if new_text != original:
        write_text(path, new_text)
        return True
    return False


INI_KEY = r"^\s*{key}\s*="


def parse_ini_values(text):
    sections, current = {}, ""
    for line in text.replace("\r\n", "\n").split("\n"):
        stripped = line.strip()
        if not stripped or stripped[0] in "#;":
            continue
        m = HEADER_RE.match(line)
        if m:
            current = m.group(1).strip()
            sections.setdefault(current, {})
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            sections.setdefault(current, {})[key.strip()] = value.strip()
    return sections


def ini_get(lines, section, key):
    scope = section_range(lines, section if section else "")
    if scope is None:
        return None, None
    pattern = re.compile(INI_KEY.format(key=re.escape(key)))
    for i in range(scope[0], scope[1]):
        if pattern.match(lines[i]):
            value = lines[i].split("=", 1)[1].strip()
            return i, value
    return None, None


def ini_set(lines, section, key, value, sep):
    idx, current = ini_get(lines, section, key)
    if idx is not None:
        lines[idx] = key + sep + value
        return
    scope = section_range(lines, section if section else "")
    if scope is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.append("[" + section + "]")
        lines.append(key + sep + value)
        return
    insert_at = scope[1]
    while insert_at > scope[0] and not lines[insert_at - 1].strip():
        insert_at -= 1
    lines.insert(insert_at, key + sep + value)


def ini_remove(lines, section, key):
    idx, _ = ini_get(lines, section, key)
    if idx is not None:
        del lines[idx]


def ini_values(ctx, spec, mode):
    values = {}
    if spec.get("values_from"):
        source = ctx.expand_path(spec["values_from"], mode)
        try:
            parsed = parse_ini_values(read_text(source))
        except OSError:
            parsed = {}
        only = re.compile(spec["sections"]) if spec.get("sections") else None
        for section, pairs in parsed.items():
            if only is None or only.search(section):
                values.setdefault(section, {}).update(pairs)
    for section, pairs in (spec.get("values") or {}).items():
        for key, value in pairs.items():
            values.setdefault(section, {})[key] = ctx.expand(str(value), mode)
    return values


def norm(value):
    return None if value is None else value.strip()


def apply_ini(ctx, spec, mode, record):
    path, exists = resolve_file(ctx, spec, mode)
    values = ini_values(ctx, spec, mode)
    wanted = []
    for section, pairs in values.items():
        if section and pairs:
            wanted.append("[" + section + "]")
        wanted.extend(key + spec.get("sep", "=") + value for key, value in pairs.items())
    hint = "\n".join(wanted) if len(wanted) <= 6 else ""
    if not exists and not spec.get("create", False):
        return False, {"code": "missing_config", "file": str(path), "line": hint}
    if not writable_target(path):
        return False, {"code": "read_only", "file": str(path), "line": hint}
    original = read_text(path) if exists else ""
    lines, trailing = split_lines(original.replace("\r\n", "\n"))
    sep = spec.get("sep", "=")
    saved = record.setdefault("ini", {}).setdefault(str(path), {})
    if exists and original and not original.endswith("\n") and not saved:
        no_eol = record.setdefault("no_eol", [])
        if str(path) not in no_eol:
            no_eol.append(str(path))
    for section, pairs in values.items():
        if section and section_range(lines, section) is None:
            created = record.setdefault("ini_sections", {}).setdefault(str(path), [])
            if section not in created:
                created.append(section)
        for key, value in pairs.items():
            slot = section + "\x1f" + key
            _, current = ini_get(lines, section, key)
            if slot not in saved:
                saved[slot] = {"prev": current, "ours": value}
            else:
                saved[slot]["ours"] = value
            if norm(current) != norm(value):
                ini_set(lines, section, key, value, sep)
    record.setdefault("ini_sep", {})[str(path)] = sep
    if not exists and any(values.values()):
        record.setdefault("created", [])
        if str(path) not in record["created"]:
            record["created"].append(str(path))
    new_text = join_lines(lines, True)
    if "\r\n" in original:
        new_text = new_text.replace("\n", "\r\n")
    if new_text != original:
        write_text(path, new_text)
        return True, None
    return False, None


def drop_empty_section(lines, section):
    for idx, line in enumerate(lines):
        m = HEADER_RE.match(line)
        if not m or m.group(1).strip() != section:
            continue
        end = idx + 1
        while end < len(lines) and not HEADER_RE.match(lines[end]):
            end += 1
        if any(l.strip() for l in lines[idx + 1:end]):
            return
        del lines[idx:end]
        if idx > 0 and not lines[idx - 1].strip() and (idx >= len(lines) or HEADER_RE.match(lines[idx])):
            del lines[idx - 1]
        if idx >= len(lines):
            while lines and not lines[-1].strip():
                lines.pop()
        return


def undo_ini(path, saved, sep, new_sections=(), no_eol=False, created=False):
    path = Path(path)
    if not path.exists() or not writable_target(path):
        return False
    original = read_text(path)
    lines, trailing = split_lines(original.replace("\r\n", "\n"))
    for slot, info in saved.items():
        section, key = slot.split("\x1f", 1)
        _, current = ini_get(lines, section, key)
        if norm(current) != norm(info.get("ours")):
            continue
        if info.get("prev") is None:
            ini_remove(lines, section, key)
        else:
            ini_set(lines, section, key, info["prev"], sep)
    for section in new_sections:
        drop_empty_section(lines, section)
    new_text = join_lines(lines, trailing)
    if "\r\n" in original:
        new_text = new_text.replace("\n", "\r\n")
    new_text = restore_eol(new_text, no_eol)
    if created and not new_text.strip():
        path.unlink()
        return True
    if new_text != original:
        write_text(path, new_text)
        return True
    return False


def json_values(ctx, spec, mode):
    values = {}
    if spec.get("values_from"):
        data = read_json(ctx.expand_path(spec["values_from"], mode), None)
        if not isinstance(data, dict):
            raise AppError("rendered values are not a JSON object")
        values.update(data)
    by_mode = spec.get("values_by_mode") or {}
    for key, value in list((spec.get("values") or {}).items()) + list((by_mode.get(mode) or by_mode.get("dark") or {}).items()):
        values[key] = ctx.expand(value, mode) if isinstance(value, str) else value
    return values


def json_indent(text):
    m = re.search(r'^([ \t]+)"', text, re.M)
    return m.group(1) if m else "    "


def dump_json(data, indent):
    return json.dumps(data, indent=indent, ensure_ascii=False) + "\n"


def apply_json(ctx, spec, mode, record):
    path, exists = resolve_file(ctx, spec, mode)
    values = json_values(ctx, spec, mode)
    append = {k: ctx.expand(v, mode) if isinstance(v, str) else v for k, v in (spec.get("append") or {}).items()}
    shown = dict(values, **{k: [v] for k, v in append.items()})
    hint = json.dumps(shown, ensure_ascii=False)
    if len(hint) > 300:
        hint = ", ".join(json.dumps(k) for k in shown)
    if not exists:
        if not spec.get("create", False):
            return False, {"code": "missing_config", "file": str(path), "line": hint}
        hidden = hidden_by_system(ctx, path)
        if hidden:
            return False, {"code": "system_config", "file": str(hidden), "line": hint}
    if not writable_target(path):
        return False, {"code": "read_only", "file": str(path), "line": hint}
    original = read_text(path) if exists else ""
    data = {}
    if original.strip():
        try:
            data = json.loads(original)
        except ValueError:
            data = None
        if not isinstance(data, dict):
            return False, {"code": "manual", "file": str(path), "line": hint}
    before = json.loads(json.dumps(data))
    if exists:
        record.setdefault("json_text", {}).setdefault(str(path), original)
    saved = record.setdefault("json", {}).setdefault(str(path), {})
    for key, value in values.items():
        slot = saved.setdefault(key, {"prev": data[key]} if key in data else {})
        slot["ours"] = value
        data[key] = value
    for key, item in append.items():
        current = data.get(key)
        slot = saved.setdefault("+" + key, {"item": item, "had": isinstance(current, list) and item in current, "missing": key not in data})
        if current is None:
            data[key] = [item]
        elif isinstance(current, list) and item not in current:
            current.append(item)
    if not exists:
        record.setdefault("created", [])
        if str(path) not in record["created"]:
            record["created"].append(str(path))
    if data != before or not exists:
        write_text(path, dump_json(data, json_indent(original)))
        return True, None
    return False, None


def undo_json(path, saved, created=False, text=None):
    path = Path(path)
    if not path.exists() or not writable_target(path):
        return False
    original = read_text(path)
    try:
        data = json.loads(original) if original.strip() else {}
    except ValueError:
        return False
    if not isinstance(data, dict):
        return False
    before = json.loads(json.dumps(data))
    for key, info in saved.items():
        if key.startswith("+"):
            name = key[1:]
            current = data.get(name)
            if isinstance(current, list) and not info.get("had") and info.get("item") in current:
                current.remove(info["item"])
                if not current and info.get("missing"):
                    del data[name]
            continue
        if key not in data or data[key] != info.get("ours"):
            continue
        if "prev" in info:
            data[key] = info["prev"]
        else:
            del data[key]
    if created and not data:
        path.unlink()
        return True
    if data == before:
        return False
    restored = dump_json(data, json_indent(original))
    if text is not None:
        try:
            if (json.loads(text) if text.strip() else {}) == data:
                restored = text
        except ValueError:
            pass
    write_text(path, restored)
    return True


def run_quiet(argv, timeout=10):
    resolved = which(argv[0])
    if not resolved:
        return 1, ""
    argv = [resolved] + list(argv[1:])
    try:
        proc = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout, text=True)
        return proc.returncode, proc.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return 1, ""


def theme_installed(ctx, name):
    bases = [ctx.home / ".themes", ctx.data_home / "themes"] + [d / "themes" for d in ctx.data_dirs] + [Path("/usr/share/themes")]
    return any((b / name).is_dir() for b in bases)


def gsettings_value(ctx, spec, mode):
    value = spec.get("value")
    if isinstance(value, dict):
        value = value.get(mode, value.get("dark"))
    return ctx.expand(str(value), mode)


def apply_gsettings(ctx, spec, mode, record):
    if not which("gsettings"):
        return False, None
    schema, key = spec["schema"], spec["key"]
    value = gsettings_value(ctx, spec, mode)
    if spec.get("requires_theme"):
        name = value.strip("'\"")
        if not theme_installed(ctx, name):
            return False, {"code": "no_theme", "file": "", "line": name}
    code, current = run_quiet(["gsettings", "get", schema, key])
    if code != 0:
        return False, None
    saved = record.setdefault("gsettings", {})
    slot = schema + "\x1f" + key
    if slot not in saved:
        saved[slot] = {"prev": current, "ours": value}
    else:
        saved[slot]["ours"] = value
    if current == value:
        return False, None
    code, _ = run_quiet(["gsettings", "set", schema, key, value])
    return code == 0, None


def undo_gsettings(saved):
    if not which("gsettings"):
        return False
    changed = False
    for slot, info in saved.items():
        schema, key = slot.split("\x1f", 1)
        code, current = run_quiet(["gsettings", "get", schema, key])
        if code != 0 or current != info.get("ours") or info.get("prev") is None:
            continue
        if run_quiet(["gsettings", "set", schema, key, info["prev"]])[0] == 0:
            changed = True
    return changed


def toml_str(value):
    return json.dumps(str(value), ensure_ascii=False)


def render(ctx, jobs, stage):
    if not jobs:
        return {}
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir(parents=True)
    config = ["[config]", ""]
    for job in jobs:
        config.append("[templates." + toml_str(job["key"]) + "]")
        config.append("input_path = " + toml_str(job["input"]))
        config.append("output_path = " + toml_str(job["stage"]))
        config.append("")
    config_path = stage / "render.toml"
    config_path.write_text("\n".join(config), encoding="utf-8")
    try:
        proc = subprocess.run(
            [ctx.matugen, "-c", str(config_path), "json", str(ctx.palette)],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=MATUGEN_TIMEOUT,
            cwd=str(stage),
        )
        message = re.sub(r"\x1b\[[0-9;]*m", "", proc.stdout.decode("utf-8", "replace")).strip()
        code = proc.returncode
    except FileNotFoundError:
        raise AppError("matugen is not installed")
    except subprocess.TimeoutExpired:
        code, message = 1, "matugen timed out"
    errors = {}
    app_ids = sorted({j["app"] for j in jobs})
    if code != 0 and len(app_ids) > 1:
        for app_id in app_ids:
            errors.update(render(ctx, [j for j in jobs if j["app"] == app_id], stage / ("isolate-" + app_id)))
        return errors
    if code != 0:
        errors[jobs[0]["app"]] = summarize_error(message)
    for job in jobs:
        if job["app"] not in errors and not Path(job["stage"]).exists():
            errors[job["app"]] = summarize_error(message) or "template was not rendered"
    return errors


def summarize_error(message):
    lines = [re.sub(r"[│╭╰─┬┤├╯╮]+", " ", l).strip() for l in message.splitlines()]
    lines = [re.sub(r"\s+", " ", l) for l in lines if l.strip()]
    keep = [l for l in lines if re.search(r"error|does not exist|not found|failed|invalid", l, re.I) and not l.startswith("Backtrace")]
    text = "; ".join(dict.fromkeys(keep or lines[-2:]))
    return text[:400]


def reload_app(commands):
    for command in commands:
        try:
            subprocess.Popen(
                ["bash", "-c", command],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
                env=dict(os.environ, PATH=search_path()),
            )
        except OSError:
            pass


def spec_active(ctx, spec, mode):
    try:
        return check_when(ctx, spec.get("when"), mode)
    except AppError:
        return False


def undo_record(record):
    changed = False
    created = set(record.get("created", []))
    no_eol = set(record.get("no_eol", []))
    padded = set(record.get("padded", []))
    for path, comment in (record.get("lines") or {}).items():
        try:
            changed |= undo_line(comment, path, path in created, path in no_eol, path in padded)
        except OSError:
            pass
    for path, saved in (record.get("ini") or {}).items():
        sep = (record.get("ini_sep") or {}).get(path, "=")
        sections = (record.get("ini_sections") or {}).get(path, [])
        try:
            changed |= undo_ini(path, saved, sep, sections, path in no_eol, path in created)
        except OSError:
            pass
    for path, saved in (record.get("json") or {}).items():
        try:
            changed |= undo_json(path, saved, path in created, (record.get("json_text") or {}).get(path))
        except OSError:
            pass
    changed |= undo_gsettings(record.get("gsettings") or {})
    for out in record.get("outputs", []):
        path = Path(out)
        if path.is_file() or path.is_symlink():
            try:
                path.unlink()
                changed = True
            except OSError:
                pass
    return changed


class Lock:
    def __init__(self, ctx):
        ctx.work.mkdir(parents=True, exist_ok=True)
        self.path = ctx.work / "apptheme.lock"

    def __enter__(self):
        self.handle = open(self.path, "w")
        fcntl.flock(self.handle, fcntl.LOCK_EX)
        return self

    def __exit__(self, *exc):
        fcntl.flock(self.handle, fcntl.LOCK_UN)
        self.handle.close()


def palette_mode(ctx, explicit):
    if explicit in ("dark", "light"):
        return explicit
    data = read_json(ctx.palette, {})
    mode = data.get("mode") if isinstance(data, dict) else None
    if isinstance(mode, str) and mode.lower() in ("dark", "light"):
        return mode.lower()
    settings = read_json(ctx.settings, {})
    theme = settings.get("theme", {}) if isinstance(settings, dict) else {}
    mode = theme.get("mode") if isinstance(theme, dict) else None
    return mode if mode in ("dark", "light") else "dark"


def apply(ctx, enabled_override=None, mode=None, force=False, only=None):
    with Lock(ctx):
        return _apply(ctx, enabled_override, mode, force, only)


def _apply(ctx, enabled_override, mode, force, only):
    apps = load_apps(ctx)
    enabled = enabled_ids(ctx, apps, enabled_override)
    state = load_state(ctx)
    mode = palette_mode(ctx, mode)
    results = {}
    for app_id in list(state["applied"].keys()):
        if app_id in enabled or (only and app_id not in only):
            continue
        record = state["applied"].pop(app_id)
        if undo_record(record):
            reload_app(record.get("reload", []))
        state["results"].pop(app_id, None)
    palette_bytes = ctx.palette.read_bytes() if ctx.palette.is_file() else None
    try:
        palette = json.loads(palette_bytes) if palette_bytes else None
    except ValueError:
        palette = None
    if not isinstance(palette, dict) or not isinstance(palette.get("colors"), dict):
        save_state(ctx, state)
        return {"ok": False, "error": "no_palette" if palette_bytes is None else "bad_palette", "apps": results}
    palette_hash = sha(palette_bytes + mode.encode())
    targets = []
    for app_id in sorted(enabled):
        app = apps.get(app_id)
        if app is None or (only and app_id not in only):
            continue
        if app.error:
            results[app_id] = {"ok": False, "error": "invalid", "detail": app.error}
            continue
        if installed(ctx, app):
            targets.append(app)
    jobs, plans = [], {}
    stage = ctx.work / "stage"
    for app in targets:
        try:
            outputs = []
            for index, tpl in enumerate(concrete(ctx, app.data["templates"], mode)):
                if spec_active(ctx, tpl, mode):
                    outputs.append((index, app.dir / tpl["input"], ctx.expand_path(tpl["output"], mode)))
        except AppError as exc:
            results[app.id] = {"ok": False, "error": "invalid", "detail": str(exc)}
            continue
        fingerprint = sha((palette_hash + app.raw_bytes() + json.dumps([str(o[2]) for o in outputs])).encode())
        previous = state["applied"].get(app.id, {})
        fresh = (
            not force
            and previous.get("fingerprint") == fingerprint
            and all(file_hash(dest) == previous.get("hashes", {}).get(str(dest)) for _, _, dest in outputs)
        )
        plans[app.id] = {"fingerprint": fingerprint, "fresh": fresh, "jobs": []}
        if fresh:
            continue
        for index, src, dest in outputs:
            job = {
                "app": app.id,
                "key": app.id + "--" + str(index),
                "input": str(src),
                "stage": str(stage / app.id / str(index)),
                "dest": dest,
            }
            jobs.append(job)
            plans[app.id]["jobs"].append(job)
    try:
        errors = render(ctx, jobs, stage) if jobs else {}
    except AppError as exc:
        errors = {job["app"]: str(exc) for job in jobs}
    for app in targets:
        plan = plans.get(app.id)
        if plan is None:
            continue
        if app.id in errors:
            results[app.id] = {"ok": False, "error": "render", "detail": errors[app.id]}
            continue
        record = state["applied"].get(app.id, {})
        changed = False
        outputs = set(record.get("outputs", []))
        hashes = dict(record.get("hashes", {}))
        write_error = None
        for job in plan["jobs"]:
            data = Path(job["stage"]).read_bytes()
            dest = job["dest"]
            try:
                if dest.is_symlink() or file_hash(dest) != sha(data):
                    atomic_write(dest, data)
                    changed = True
            except OSError as exc:
                write_error = ctx.tilde(dest) + ": " + (exc.strerror or str(exc))
                break
            outputs.add(str(dest))
            hashes[str(dest)] = sha(data)
        record["outputs"] = sorted(outputs)
        record["hashes"] = hashes
        if write_error:
            record.pop("fingerprint", None)
            record["reload"] = as_list(app.data.get("reload"))
            if any(record.get(k) for k in ("outputs", "lines", "ini", "gsettings", "json")):
                state["applied"][app.id] = record
            results[app.id] = {"ok": False, "error": "write", "detail": write_error}
            continue
        issues = []
        try:
            specs = concrete(ctx, app.data.get("integrate", []), mode)
        except AppError as exc:
            specs, issues = [], [{"code": "failed", "file": "", "line": str(exc)}]
        for spec in specs:
            if not spec_active(ctx, spec, mode):
                continue
            try:
                if spec["type"] == "line":
                    did, issue = apply_line(ctx, spec, mode, record)
                elif spec["type"] == "ini":
                    did, issue = apply_ini(ctx, spec, mode, record)
                elif spec["type"] == "json":
                    did, issue = apply_json(ctx, spec, mode, record)
                else:
                    did, issue = apply_gsettings(ctx, spec, mode, record)
            except (OSError, AppError, re.error) as exc:
                did, issue = False, {"code": "failed", "file": "", "line": str(exc)}
            changed |= did
            if issue:
                issues.append(issue)
        record["fingerprint"] = plan["fingerprint"]
        record["reload"] = as_list(app.data.get("reload"))
        state["applied"][app.id] = record
        if changed:
            reload_app(record["reload"])
        results[app.id] = {"ok": True, "changed": changed, "issues": issues}
    for app_id in list(state["results"]):
        if app_id not in enabled and not (only and app_id not in only):
            state["results"].pop(app_id)
    state["results"].update(results)
    save_state(ctx, state)
    return {"ok": all(r.get("ok") for r in results.values()), "mode": mode, "apps": results}


def undo(ctx, ids):
    with Lock(ctx):
        state = load_state(ctx)
        apps = load_apps(ctx)
        done = []
        for app_id in ids:
            record = state["applied"].pop(app_id, None)
            if record is None:
                continue
            if undo_record(record):
                app = apps.get(app_id)
                reload_app(as_list(app.data.get("reload")) if app and not app.error else record.get("reload", []))
            state["results"].pop(app_id, None)
            done.append(app_id)
        save_state(ctx, state)
        return {"ok": True, "undone": done}


def list_apps(ctx):
    apps = load_apps(ctx)
    enabled = enabled_ids(ctx, apps)
    state = load_state(ctx)

    def order(app):
        category = app.data.get("category")
        return (CATEGORIES.index(category) if category in CATEGORIES else len(CATEGORIES), app.name.lower())

    out = []
    for app in sorted(apps.values(), key=order):
        is_installed = True if app.error else installed(ctx, app)
        outputs = []
        if not app.error:
            try:
                templates = concrete(ctx, app.data.get("templates", []), "dark")
            except AppError:
                templates = []
            for tpl in templates:
                try:
                    if spec_active(ctx, tpl, "dark"):
                        outputs.append(ctx.tilde(ctx.expand_path(tpl["output"])))
                except AppError:
                    pass
        result = state["results"].get(app.id) or {}
        issues = list(result.get("issues") or []) if app.id in enabled else []
        requires = app.data.get("requires") or {}
        if requires and not app.error and not check_when(ctx, {"bin": requires.get("bin", [])}):
            issues.append({"code": "requires", "file": "", "line": requires.get("name", "")})
        for var, accepted in (app.data.get("require_env") or {}).items():
            if accepted and os.environ.get(var, "") not in accepted:
                issues.append({"code": "env", "file": var, "line": var + "=" + accepted[0]})
        for issue in issues:
            path = issue.get("file") or ""
            issue["display"] = ctx.tilde(path) if os.path.isabs(path) else path
        error = app.error or ""
        if not error and result and not result.get("ok"):
            error = result.get("detail") or result.get("error") or ""
        out.append({
            "id": app.id,
            "name": app.name,
            "category": app.data.get("category") if app.data.get("category") in CATEGORIES else "apps",
            "icon": app.data.get("icon", ""),
            "hint": app.data.get("hint", ""),
            "installed": is_installed,
            "enabled": app.id in enabled,
            "default": bool(app.data.get("default")) and app.builtin,
            "applied": app.id in state["applied"],
            "builtin": app.builtin,
            "custom": app.custom,
            "dir": str(app.dir),
            "outputs": outputs,
            "error": error,
            "issues": issues,
        })
    return {"ok": True, "userDir": str(ctx.user_dir), "apps": out}


def customize(ctx, app_id):
    if not ID_RE.match(app_id):
        raise AppError("invalid id")
    target = ctx.user_dir / app_id
    if target.exists():
        return {"ok": True, "dir": str(target)}
    source = ctx.builtin_dir / app_id
    if not source.is_dir():
        raise AppError("unknown app")
    ctx.user_dir.mkdir(parents=True, exist_ok=True)
    tmp = ctx.user_dir / ("." + app_id + ".tmp")
    if tmp.exists():
        shutil.rmtree(tmp)
    shutil.copytree(source, tmp)
    for root, dirs, files in os.walk(tmp):
        for name in dirs + files:
            os.chmod(os.path.join(root, name), 0o755 if name in dirs else 0o644)
    os.chmod(tmp, 0o755)
    os.replace(tmp, target)
    return {"ok": True, "dir": str(target)}


def reset(ctx, app_id):
    if not ID_RE.match(app_id):
        raise AppError("invalid id")
    target = ctx.user_dir / app_id
    if not target.is_dir():
        return {"ok": True, "backup": ""}
    backup_root = ctx.work / "backup"
    backup_root.mkdir(parents=True, exist_ok=True)
    backup = backup_root / (app_id + "-" + time.strftime("%Y%m%d-%H%M%S"))
    n = 1
    while backup.exists():
        backup = backup_root / (app_id + "-" + time.strftime("%Y%m%d-%H%M%S") + "-" + str(n))
        n += 1
    shutil.move(str(target), str(backup))
    return {"ok": True, "backup": str(backup)}


def main(argv=None):
    parser = argparse.ArgumentParser(prog="apptheme")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    p_apply = sub.add_parser("apply")
    p_apply.add_argument("--enabled")
    p_apply.add_argument("--mode", choices=["dark", "light"])
    p_apply.add_argument("--force", action="store_true")
    p_apply.add_argument("--only")
    p_undo = sub.add_parser("undo")
    p_undo.add_argument("ids", nargs="+")
    p_custom = sub.add_parser("customize")
    p_custom.add_argument("id")
    p_reset = sub.add_parser("reset")
    p_reset.add_argument("id")
    args = parser.parse_args(argv)
    ctx = Context()
    try:
        if args.cmd == "list":
            result = list_apps(ctx)
        elif args.cmd == "apply":
            enabled = None if args.enabled is None else [i for i in args.enabled.split(",") if i]
            only = None if not args.only else set(args.only.split(","))
            result = apply(ctx, enabled, args.mode, args.force, only)
        elif args.cmd == "undo":
            result = undo(ctx, args.ids)
        elif args.cmd == "customize":
            result = customize(ctx, args.id)
        else:
            result = reset(ctx, args.id)
    except AppError as exc:
        result = {"ok": False, "error": str(exc)}
    except Exception as exc:
        result = {"ok": False, "error": "internal", "detail": type(exc).__name__ + ": " + str(exc)}
    sys.stdout.write(json.dumps(result, ensure_ascii=False) + "\n")
    return 0 if result.get("ok", True) else 1


if __name__ == "__main__":
    sys.exit(main())
