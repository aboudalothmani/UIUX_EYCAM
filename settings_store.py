"""تحميل وحفظ إعدادات المستخدم (JSON)."""
import json
import os

SETTINGS_FILENAME = "user_settings.json"


def settings_path() -> str:
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), SETTINGS_FILENAME)


def load_json(defaults: dict) -> dict:
    path = settings_path()
    if not os.path.isfile(path):
        return dict(defaults)
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            out = dict(defaults)
            out.update(data)
            return out
    except (OSError, json.JSONDecodeError):
        pass
    return dict(defaults)


def save_json(data: dict) -> None:
    path = settings_path()
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except OSError:
        pass
