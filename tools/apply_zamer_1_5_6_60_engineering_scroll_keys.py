from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCREEN = ROOT / 'zamer-app' / 'lib' / 'screens' / 'engineering_screen.dart'


def replace_in_section(text: str, start: str, end: str, old: str, new: str, label: str) -> str:
    a = text.find(start)
    if a < 0:
        raise SystemExit(f'{label}: start marker missing')
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f'{label}: end marker missing')
    section = text[a:b]
    count = section.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match in section, found {count}')
    section = section.replace(old, new, 1)
    return text[:a] + section + text[b:]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


text = SCREEN.read_text()
if "PageStorageKey<String>('engineering-ceiling')" in text:
    print('engineering +60 scroll keys already applied')
    raise SystemExit(0)

listview = "    return ListView(\n      padding: const EdgeInsets.all(12),\n"
text = replace_in_section(
    text,
    "  Widget _ceiling(RoomFace face, RoomMeta meta) {\n",
    "  Widget _warmFloor(RoomFace face, RoomMeta meta) {\n",
    listview,
    "    return ListView(\n      key: const PageStorageKey<String>('engineering-ceiling'),\n      padding: const EdgeInsets.all(12),\n",
    'ceiling scroll key',
)
text = replace_in_section(
    text,
    "  Widget _warmFloor(RoomFace face, RoomMeta meta) {\n",
    "  Widget _routes(RoomFace face, RoomMeta meta) => ListView(\n",
    listview,
    "    return ListView(\n      key: const PageStorageKey<String>('engineering-warm-floor'),\n      padding: const EdgeInsets.all(12),\n",
    'warm floor scroll key',
)
text = replace_once(
    text,
    "  Widget _routes(RoomFace face, RoomMeta meta) => ListView(\n    padding: const EdgeInsets.all(12),\n",
    "  Widget _routes(RoomFace face, RoomMeta meta) => ListView(\n    key: const PageStorageKey<String>('engineering-routes'),\n    padding: const EdgeInsets.all(12),\n",
    'routes scroll key',
)

SCREEN.write_text(text)
print('Applied independent engineering scroll positions for +60')
