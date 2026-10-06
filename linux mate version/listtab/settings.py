"""Ajustes persistentes del usuario: ~/.config/listtab/settings.json"""
import json
import os

PATH = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "listtab", "settings.json")

DEFAULTS = {
    # True: ventanas de TODOS los escritorios virtuales; False: solo las del escritorio actual
    "all_workspaces": True,
}


def load():
    data = dict(DEFAULTS)
    try:
        with open(PATH) as f:
            data.update({k: v for k, v in json.load(f).items() if k in DEFAULTS})
    except (OSError, ValueError):
        pass
    return data


def get(key):
    return load()[key]


def set(key, value):
    data = load()
    data[key] = value
    os.makedirs(os.path.dirname(PATH), exist_ok=True)
    with open(PATH, "w") as f:
        json.dump(data, f, indent=2)
    return value
