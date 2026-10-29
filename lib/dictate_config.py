"""Reads and edits dictate.toml for ostt-dictate: the [apps] table, and
pause_media, which is true unless set to false.

    dictate_config.py apps <config>              JSON {"apps": {class: entry}, "invalid": [class],
                                                 "pause_media": bool or null if not valid}
    dictate_config.py lookup <config> <class>    JSON entry of one app, or {} if it has none
    dictate_config.py map <config> <class> [<action> [--screenshot]]
    dictate_config.py pause-media <config>       true or false; true if not valid
    dictate_config.py pause-media <config> on|off

An entry is {"action": str, "screenshot": bool}. Errors are printed as one
line on stderr with exit status 1.
"""

import json
import os
import re
import sys
import tempfile
import tomllib

EXAMPLE = '{ action = "ghostwriter", screenshot = true }'


class ConfigError(Exception):
    pass


def load(path):
    """The parsed file, or {} if it does not exist."""
    try:
        with open(path, "rb") as f:
            document = tomllib.load(f)
    except FileNotFoundError:
        return {}
    except tomllib.TOMLDecodeError as e:
        raise ConfigError(f"{path} is not valid TOML: {e}") from e
    if not isinstance(document.get("apps", {}), dict):
        raise ConfigError(f"[apps] in {path} must be a table")
    return document


def entry(value):
    """A valid entry, or None."""
    if (isinstance(value, dict) and isinstance(value.get("action"), str)
            and isinstance(value.get("screenshot", False), bool)):
        return {"action": value["action"], "screenshot": value.get("screenshot", False)}
    return None


def pause_media(document):
    """Whether dictation pauses media players, or None if the value is not valid."""
    value = document.get("pause_media", True)
    return value if isinstance(value, bool) else None


def apps(path):
    """Every app's entry; a malformed entry affects only its own app."""
    document = load(path)
    valid, invalid = {}, []
    for app, value in document.get("apps", {}).items():
        if (parsed := entry(value)) is not None:
            valid[app] = parsed
        else:
            invalid.append(app)
    return {"apps": valid, "invalid": invalid, "pause_media": pause_media(document)}


def lookup(path, app):
    """One app's entry, or {} if it has none."""
    value = load(path).get("apps", {}).get(app)
    if value is None:
        return {}
    if (parsed := entry(value)) is None:
        raise ConfigError(f"The entry for {app} in {path} is not valid; it must look like {EXAMPLE}")
    return parsed


def _key_of(line):
    """The key a one-line `key = value` defines, or None."""
    try:
        parsed = tomllib.loads(line)
    except tomllib.TOMLDecodeError:
        return None
    return next(iter(parsed)) if len(parsed) == 1 else None


def edit(text, app, new_entry):
    """`text` with app's line under [apps] replaced, added or removed.

    Only that line changes, so the rest of the file stays as written. The
    result must parse to the original document with just that entry changed;
    anything else (an [apps] this cannot edit line by line) is refused.
    """
    try:
        before = tomllib.loads(text)
    except tomllib.TOMLDecodeError as e:
        raise ConfigError(f"not valid TOML: {e}") from e
    if not isinstance(before.get("apps", {}), dict):
        raise ConfigError("[apps] must be a table")
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.splitlines()

    header = re.compile(r"\s*\[\s*apps\s*\]\s*(#.*)?")
    start = next((i for i, line in enumerate(lines) if header.fullmatch(line)), None)
    if start is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.append("[apps]")
        start = len(lines) - 1
    end = next((i for i in range(start + 1, len(lines)) if lines[i].lstrip().startswith("[")),
               len(lines))
    section = [line for line in lines[start + 1:end] if _key_of(line) != app]
    if new_entry:
        last_key = max((i for i, line in enumerate(section) if _key_of(line) is not None), default=-1)
        value = json.dumps(new_entry["action"], ensure_ascii=False)
        flag = "true" if new_entry["screenshot"] else "false"
        section.insert(last_key + 1,
                       f"{json.dumps(app, ensure_ascii=False)} = {{ action = {value}, screenshot = {flag} }}")
    result = newline.join(lines[:start + 1] + section + lines[end:]) + newline

    expected = dict(before)
    expected["apps"] = dict(before.get("apps", {}))
    if new_entry:
        expected["apps"][app] = new_entry
    else:
        expected["apps"].pop(app, None)
    try:
        after = tomllib.loads(result)
    except tomllib.TOMLDecodeError:
        after = None
    if after != expected:
        raise ConfigError(f"could not change {app} safely; edit [apps] by hand")
    return result


def edit_pause_media(text, value):
    """`text` with its top-level pause_media line replaced, or added before
    the first table. Refused, like edit(), unless only that value changes."""
    try:
        before = tomllib.loads(text)
    except tomllib.TOMLDecodeError as e:
        raise ConfigError(f"not valid TOML: {e}") from e
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.splitlines()
    line = f"pause_media = {'true' if value else 'false'}"
    first_table = next((i for i, text_line in enumerate(lines) if text_line.lstrip().startswith("[")), len(lines))
    current = next((i for i in range(first_table) if _key_of(lines[i]) == "pause_media"), None)
    if current is not None:
        lines[current] = line
    elif first_table < len(lines):
        lines[first_table:first_table] = [line, ""]
    else:
        lines.append(line)
    result = newline.join(lines) + newline

    try:
        after = tomllib.loads(result)
    except tomllib.TOMLDecodeError:
        after = None
    if after != {**before, "pause_media": value}:
        raise ConfigError("could not change pause_media safely; edit it by hand")
    return result


def change(path, edit_text):
    """Applies edit_text to the file, replacing it in one rename."""
    try:
        with open(path, newline="") as f:
            text = f.read()
    except FileNotFoundError:
        text = ""
    try:
        result = edit_text(text)
    except ConfigError as e:
        raise ConfigError(f"{path}: {e}") from e
    target = os.path.realpath(path)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(target), prefix=".dictate.")
    try:
        with os.fdopen(fd, "w", newline="") as f:
            f.write(result)
        os.replace(tmp, target)
    except BaseException:
        os.unlink(tmp)
        raise


def map_app(path, app, action, screenshot):
    """Sets or clears one app's entry."""
    new_entry = {"action": action, "screenshot": screenshot} if action else None
    change(path, lambda text: edit(text, app, new_entry))


def main(args):
    if args[:1] == ["map"] and len(args) >= 3 and not args[2]:
        raise ConfigError("Usage: ostt-dictate map <class> [<action> [--screenshot]]")
    match args:
        case ["apps", path]:
            print(json.dumps(apps(path)))
        case ["lookup", path, app]:
            print(json.dumps(lookup(path, app)))
        case ["map", path, app]:
            map_app(path, app, "", False)
        case ["map", path, app, action] if not action.startswith("-"):
            map_app(path, app, action, False)
        case ["map", path, app, action, "--screenshot"] if not action.startswith("-"):
            map_app(path, app, action, True)
        case ["map", *_]:
            raise ConfigError("Usage: ostt-dictate map <class> [<action> [--screenshot]]")
        case ["pause-media", path]:
            print(json.dumps(pause_media(load(path)) is not False))
        case ["pause-media", path, ("on" | "off") as value]:
            change(path, lambda text: edit_pause_media(text, value == "on"))
        case ["pause-media", *_]:
            raise ConfigError("Usage: ostt-dictate pause-media [on|off]")
        case _:
            raise ConfigError("Usage: dictate_config.py apps|lookup|map ... (see its docstring)")


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (ConfigError, OSError) as e:
        print(e, file=sys.stderr)
        sys.exit(1)
